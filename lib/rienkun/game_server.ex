defmodule Rienkun.GameServer do
  use GenServer

  alias Rienkun.PubSub

  # Client Code

  def start_link(room) do
    GenServer.start(__MODULE__, room, name: {:via, Registry, {Rienkun.RoomRegistry, room}})
  end

  def get_pid(room) do
    GenServer.whereis({:via, Registry, {Rienkun.RoomRegistry, room}})
  end

  def start_game(room) do
    GenServer.call(get_pid(room), {:start_game})
  end

  def add_clue(room, player, clue) do
    GenServer.call(get_pid(room), {:add_clue, player, clue})
  end

  def invalidate_clue(room, player) do
    GenServer.call(get_pid(room), {:invalidate_clue, player})
  end

  def validate_clue(room, player) do
    GenServer.call(get_pid(room), {:validate_clue, player})
  end

  def validation_vote(room, player) do
    GenServer.call(get_pid(room), {:validation_vote, player})
  end

  def guess_word(room, word) do
    GenServer.call(get_pid(room), {:guess_word, word})
  end

  def win_vote(room, player, vote) do
    GenServer.call(get_pid(room), {:win_vote, player, vote})
  end

  def reset_vote(room, player) do
    GenServer.call(get_pid(room), {:reset_vote, player})
  end

  def get_state(room) do
    GenServer.call(get_pid(room), {:get_state})
  end

  # GenServer code

  @impl true
  def init(room) do
    Phoenix.PubSub.subscribe(PubSub, "rienkun:presence:" <> room)

    {:ok, %{
      room: room,
      state: :waiting_for_players,
      word: nil,
      clues: %{},
      valid_clues: %{},
      players: %{},
      guess_order: [],
      guesser: nil,
      wins: 0,
      losses: 0,
      word_tried: nil,
      reset_votes: %{},
      validation_votes: %{},
      win_votes: %{},
    }}
  end

  @impl true
  def handle_call({:start_game}, _from, state) do
    guesser = List.first(state.guess_order)
    guess_order = List.insert_at(List.delete_at(state.guess_order, 0), -1, guesser)
    word =
      File.read!("priv/words.txt")
      |> String.split("\n")
      |> Enum.random()
    state = %{state |
      state: :enter_clues,
      guesser: guesser,
      guess_order: guess_order,
      word: word,
      clues: %{},
      valid_clues: %{},
      word_tried: nil,
      reset_votes: %{},
      validation_votes: %{},
      win_votes: %{},
    }
    {:reply, :ok, broadcast!(state)}
  end

  @impl true
  def handle_call({:add_clue, player, clue}, _from, state) do
    clues = Map.put(state.clues, player, clue)
    state =
      if Enum.count(clues) == Enum.count(state.players) - 1 do
        %{state | state: :validate_clues, clues: clues, valid_clues: clues}
      else
        %{state | clues: clues}
      end
    {:reply, :ok, broadcast!(state)}
  end

  @impl true
  def handle_call({:invalidate_clue, player}, _from, %{state: :validate_clues} = state) do
    state = %{state | valid_clues: Map.drop(state.valid_clues, [player])}
    {:reply, :ok, broadcast!(state)}
  end
  def handle_call({:invalidate_clue, _player}, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_call({:validate_clue, player}, _from, %{state: :validate_clues} = state) do
    state = %{state | valid_clues: Map.put(state.valid_clues, player, state.clues[player])}
    {:reply, :ok, broadcast!(state)}
  end
  def handle_call({:validate_clue, _player}, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_call({:validation_vote, player}, _from, %{state: :validate_clues} = state) do
    validation_votes = Map.put(state.validation_votes, player, true)
    state =
      if Enum.count(validation_votes) > (Enum.count(state.players) - 1) / 2 do
        %{state | state: :guess_word, validation_votes: %{}}
      else
        %{state | validation_votes: validation_votes}
      end
    {:reply, :ok, broadcast!(state)}
  end
  def handle_call({:validation_vote, _player}, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_call({:guess_word, word}, _from, %{state: :guess_word} = state) do
    state = %{state | state: :guess_vote, word_tried: word}
    {:reply, :ok, broadcast!(state)}
  end
  def handle_call({:guess_word, _player}, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_call({:win_vote, player, vote}, _from, %{state: :guess_vote} = state) do
    win_votes = Map.put(state.win_votes, player, vote)
    total_same = win_votes |> Enum.filter(&(elem(&1, 1) == vote)) |> Enum.count()
    state =
      if total_same > (Enum.count(state.players) - 1) / 2 do
        if vote == :win do
          %{state | state: :win, wins: state.wins + 1, win_votes: win_votes}
        else
          %{state | state: :lose, losses: state.losses + 1, win_votes: win_votes}
        end
      else
        %{state | win_votes: win_votes}
      end
    {:reply, :ok, broadcast!(state)}
  end
  def handle_call({:win_vote, _player}, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_call({:reset_vote, player}, _from, state) do
    reset_votes = Map.put(state.reset_votes, player, true)
    state =
      if Enum.count(reset_votes) > Enum.count(state.players) / 2 do
        %{state | state: :ready, reset_votes: %{}}
      else
        %{state | reset_votes: reset_votes}
      end
    {:reply, :ok, broadcast!(state)}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, state) do
    state =
      state
      |> handle_joins(diff.joins)
      |> handle_leaves(diff.leaves)

    if Enum.count(state.players) > 0 do
      {:noreply, broadcast!(state)}
    else
      {:stop, :normal, state}
    end
  end

  defp handle_joins(state, players) do
    joins = Enum.map(players, fn {id, %{metas: [meta|_]}} -> {id, meta} end) |> Map.new()
    players = Map.merge(state.players, joins)
    guess_order = Enum.uniq(state.guess_order ++ Map.keys(joins))
    if Enum.count(players) >= 3 do
      if state.state == :waiting_for_players do
        %{state | state: :ready, players: players, guess_order: guess_order}
      else
        %{state | players: players, guess_order: guess_order}
      end
    else
      %{state | state: :waiting_for_players, players: players, guess_order: guess_order}
    end
  end

  def handle_leaves(state, players) do
    leaves = Enum.map(players, fn {id, %{metas: [meta|_]}} -> {id, meta} end) |> Map.new()
    players = Map.drop(state.players, Map.keys(leaves))
    guess_order = state.guess_order -- Map.keys(leaves)
    case Enum.count(players) do
      x when x < 3 ->
        %{state | state: :waiting_for_players, players: players, guess_order: guess_order}
      _ ->
        %{state | players: players, guess_order: guess_order}
    end
  end

  defp broadcast!(state) do
    Phoenix.PubSub.broadcast!(PubSub, "rienkun:room:" <> state.room, %{event: :state_changed, payload: state})
    state
  end
end
defmodule Rienkun.GameServer do
  use GenServer

  alias Rienkun.PubSub

  @presence "rienkun:presence"
  @game "rienkun:game"

  # Client Code

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_game() do
    GenServer.call(__MODULE__, {:start_game})
  end

  def add_clue(player, clue) do
    GenServer.call(__MODULE__, {:add_clue, player, clue})
  end

  def guess_word(word) do
    GenServer.call(__MODULE__, {:guess_word, word})
  end

  def invalidate_clue(player) do
    GenServer.call(__MODULE__, {:invalidate_clue, player})
  end

  def validate_clue(player) do
    GenServer.call(__MODULE__, {:validate_clue, player})
  end

  def validation_done() do
    GenServer.call(__MODULE__, {:validation_done})
  end

  def get_state() do
    GenServer.call(__MODULE__, {:get_state})
  end

  # GenServer code

  @impl true
  def init(:ok) do
    Phoenix.PubSub.subscribe(PubSub, @presence)

    {:ok, %{
      state: :waiting_for_players,
      word: nil,
      clues: %{},
      valid_clues: %{},
      players: [],
      guesser: nil,
      wins: 0,
      losses: 0,
      word_tried: nil,
    }}
  end

  @impl true
  def handle_call({:start_game}, _from, state) do
    guesser = List.first(state.players)
    players = List.insert_at(Enum.drop(state.players, 0), -1, guesser)
    word =
      File.read!("priv/words.txt")
      |> String.split("\n")
      |> Enum.random()
    state = %{state | state: :enter_clues, guesser: guesser.id, players: players, word: word, clues: %{}, valid_clues: %{}, word_tried: nil}
    broadcast!(state)
    {:reply, :ok, state}
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
    broadcast!(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:invalidate_clue, player}, _from, %{state: :validate_clues} = state) do
    state = %{state | valid_clues: Map.drop(state.valid_clues, [player])}
    broadcast!(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:validate_clue, player}, _from, %{state: :validate_clues} = state) do
    state = %{state | valid_clues: Map.put(state.valid_clues, player, state.clues[player])}
    broadcast!(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:validation_done}, _from, %{state: :validate_clues} = state) do
    state = %{state | state: :guess_word}
    broadcast!(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:guess_word, word}, _from, %{state: :guess_word} = state) do
    state =
      if String.downcase(word) == String.downcase(state.word) do
        %{state | state: :win, wins: state.wins + 1}
      else
        %{state | state: :lose, losses: state.losses + 1, word_tried: word}
      end
    broadcast!(state)
    {:reply, :ok, state}
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

    broadcast!(state)
    {:noreply, state}
  end

  defp handle_joins(state, players) do
    joins = Enum.map(players, fn {id, %{metas: [meta|_]}} -> Map.put(meta, :id, id) end)
    players = Enum.uniq(state.players ++ joins)
    if Enum.count(players) >= 3 do
      if state.state == :waiting_for_players do
        %{state | state: :ready, players: players}
      else
        %{state | players: players}
      end
    else
      %{state | state: :waiting_for_players, players: players, word: nil}
    end
  end

  def handle_leaves(state, players) do
    leaves = Enum.map(players, fn {id, %{metas: [meta|_]}} -> Map.put(meta, :id, id) end)
    players = state.players -- leaves
    case Enum.count(players) do
      0 ->
        %{state | state: :waiting_for_players, players: players, word: nil, clues: %{}, wins: 0, losses: 0}
      x when x < 3 ->
        %{state | state: :waiting_for_players, players: players, word: nil, clues: %{}}
      _ ->
        if Enum.member?(players, state.guesser) do
          %{state | players: players}
        else
          %{state | state: :ready, players: players, guesser: nil}
        end
    end
  end

  defp broadcast!(state) do
    Phoenix.PubSub.broadcast!(PubSub, @game, %{event: :state_changed, payload: state})
  end
end
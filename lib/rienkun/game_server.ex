defmodule Rienkun.GameServer do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn ->
      %{
        state: :waiting_for_players,
        word: nil,
        clues: %{},
        valid_clues: %{},
        players: [],
        guesser: nil,
        wins: 0,
        losses: 0,
      }
    end, name: __MODULE__)
  end

  defp broadcast!() do
    state = Agent.get(__MODULE__, fn state -> state end)
    Phoenix.PubSub.broadcast!(Rienkun.PubSub, "rienkun:game", %{event: :state_changed, payload: state})
  end

  def get_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def player_join(player) do
    Agent.update(__MODULE__, fn state ->
      players = Enum.uniq([player | state.players])
      if Enum.count(players) >= 3 do
        if state.state == :waiting_for_players do
          %{state | state: :ready, players: players}
        else
          %{state | players: players}
        end
      else
        %{state | state: :waiting_for_players, players: players, word: nil}
      end
    end)
    broadcast!()
  end

  def player_refresh(players) do
    Agent.update(__MODULE__, fn state ->
      if Enum.count(players) >= 3 do
        %{state | players: players}
      else
        %{state | state: :waiting_for_players, players: players, word: nil}
      end
    end)
    broadcast!()
  end

  def player_leave(player) do
    Agent.update(__MODULE__, fn state ->
      players = List.delete(state.players, player)
      if Enum.count(players) >= 3 do
        %{state | players: players}
      else
        %{state | state: :waiting_for_players, players: players, word: nil, clues: %{}}
      end
    end)
    broadcast!()
  end

  def start_game() do
    Agent.update(__MODULE__, fn state ->
      guesser = List.last(state.players)
      players = [guesser | Enum.drop(state.players, -1) ]
      word =
        File.read!("priv/words.txt")
        |> String.split("\n")
        |> Enum.random()
      %{state | state: :enter_clues, guesser: guesser, players: players, word: word, clues: %{}, valid_clues: %{}}
    end)
    broadcast!()
  end

  def add_clue(player, clue) do
    Agent.update(__MODULE__, fn %{state: :enter_clues} = state ->
      clues = Map.put(state.clues, player, clue)
      if Enum.count(clues) == Enum.count(state.players) - 1 do
        %{state | state: :validate_clues, clues: clues, valid_clues: clues}
      else
        %{state | clues: clues}
      end
    end)
    broadcast!()
  end

  def invalidate_clue(player) do
    Agent.update(__MODULE__, fn %{state: :validate_clues} = state ->
      %{state | valid_clues: Map.drop(state.valid_clues, [player])}
    end)
    broadcast!()
  end

  def validate_clue(player) do
    Agent.update(__MODULE__, fn %{state: :validate_clues} = state ->
      %{state | valid_clues: Map.put(state.valid_clues, player, state.clues[player])}
    end)
    broadcast!()
  end

  def validation_done() do
    Agent.update(__MODULE__, fn %{state: :validate_clues} = state ->
      %{state | state: :guess_word}
    end)
    broadcast!()
  end

  def guess_word(word) do
    Agent.update(__MODULE__, fn %{state: :guess_word} = state ->
      if word == state.word do
        %{state | state: :win, wins: state.wins + 1}
      else
        %{state | state: :lose, losses: state.losses + 1}
      end
    end)
    broadcast!()
  end
end
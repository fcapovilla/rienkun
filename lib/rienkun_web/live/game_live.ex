defmodule RienkunWeb.GameLive do
  use RienkunWeb, :live_view

  alias RienkunWeb.Presence
  alias Rienkun.PubSub

  @presence "rienkun:presence"
  @game "rienkun:game"

  @impl true
  def mount(_params, session, socket) do
    name = session["name"]
    player_id = session["player_id"]
    if connected?(socket) do
      {:ok, _} = Presence.track(self(), @presence, player_id, %{
        name: name,
      })

      Phoenix.PubSub.subscribe(PubSub, @game)
    end

    {
      :ok,
      socket
      |> assign(:current_user, player_id)
      |> assign(:users, %{})
      |> assign(:game, Rienkun.GameServer.get_state())
    }
  end

  @impl true
  def handle_info(%{event: :state_changed, payload: state}, socket) do
    {
      :noreply,
      socket
      |> assign(:game, state)
    }
  end

  @impl true
  def handle_event("start_game", _value, socket) do
    Rienkun.GameServer.start_game()
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_clue", %{"word" => word}, socket) do
    Rienkun.GameServer.add_clue(socket.assigns.current_user, word)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_clue", %{"id" => id}, socket) do
    Rienkun.GameServer.validate_clue(id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("invalidate_clue", %{"id" => id}, socket) do
    Rienkun.GameServer.invalidate_clue(id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validation_done", _value, socket) do
    Rienkun.GameServer.validation_done()
    {:noreply, socket}
  end

  @impl true
  def handle_event("guess_word", %{"word" => word}, socket) do
    Rienkun.GameServer.guess_word(word)
    {:noreply, socket}
  end
end

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
        joined_at: :os.system_time(:seconds)
      })

      Phoenix.PubSub.subscribe(PubSub, @presence)
      Phoenix.PubSub.subscribe(PubSub, @game)
    end

    {
      :ok,
      socket
      |> assign(:current_user, player_id)
      |> assign(:users, %{})
      |> assign(:game, Rienkun.GameServer.get_state())
      |> handle_joins(Presence.list(@presence))
    }
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_joins(socket, joins) do
    Enum.reduce(joins, socket, fn {user, %{metas: [meta| _]}}, socket ->
      Rienkun.GameServer.player_join(user)
      assign(socket, :users, Map.put(socket.assigns.users, user, meta))
    end)
  end

  defp handle_leaves(socket, leaves) do
    Enum.reduce(leaves, socket, fn {user, _}, socket ->
      Rienkun.GameServer.player_leave(user)
      assign(socket, :users, Map.delete(socket.assigns.users, user))
    end)
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

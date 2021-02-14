defmodule RienkunWeb.GameLive do
  use RienkunWeb, :live_view

  alias RienkunWeb.Presence
  alias Rienkun.PubSub

  @impl true
  def mount(%{"room" => room}, %{"name" => name, "player_id" => player_id}, socket) do
    if connected?(socket) do
      {:ok, _} = Presence.track(self(), "rienkun:presence:" <> room, player_id, %{
        name: name,
      })

      Phoenix.PubSub.subscribe(PubSub, "rienkun:room:" <> room)
    end

    if !Rienkun.GameServer.get_pid(room) do
      Rienkun.GameSupervisor.start_game(room)
    end

    {
      :ok,
      socket
      |> assign(:current_user, player_id)
      |> assign(:users, %{})
      |> assign(:game, Rienkun.GameServer.get_state(room))
    }
  end
  def mount(%{"room" => room}, _session, socket) do
    {:ok, socket |> redirect(to: Routes.login_path(socket, :index, room: room))}
  end

  @impl true
  def handle_info(%{event: :state_changed, payload: state}, socket) do
    {
      :noreply,
      if socket.assigns.game.state != state.state do
        socket |> clear_flash() |> assign(:game, state)
      else
        socket |> assign(:game, state)
      end
    }
  end

  @impl true
  def handle_event("start_game", _value, socket) do
    Rienkun.GameServer.start_game(socket.assigns.game.room)
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_clue", %{"word" => word}, socket) do
    cond do
      word == "" ->
        {:noreply, socket |> put_flash(:error, "Votre indice ne peut pas être vide!")}
      String.contains?(word, " ") ->
        {:noreply, socket |> put_flash(:error, "Votre indice doit être un seul mot!")}
      true ->
        Rienkun.GameServer.add_clue(socket.assigns.game.room, socket.assigns.current_user, word)
        {:noreply, socket |> clear_flash()}
    end
  end

  @impl true
  def handle_event("validate_clue", %{"id" => id}, socket) do
    Rienkun.GameServer.validate_clue(socket.assigns.game.room, id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("invalidate_clue", %{"id" => id}, socket) do
    Rienkun.GameServer.invalidate_clue(socket.assigns.game.room, id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validation_vote", _value, socket) do
    Rienkun.GameServer.validation_vote(socket.assigns.game.room, socket.assigns.current_user)
    {:noreply, socket}
  end

  @impl true
  def handle_event("win_vote", %{"vote" => "win"}, socket) do
    Rienkun.GameServer.win_vote(socket.assigns.game.room, socket.assigns.current_user, :win)
    {:noreply, socket}
  end

  @impl true
  def handle_event("win_vote", %{"vote" => "lose"}, socket) do
    Rienkun.GameServer.win_vote(socket.assigns.game.room, socket.assigns.current_user, :lose)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_vote", _value, socket) do
    Rienkun.GameServer.reset_vote(socket.assigns.game.room, socket.assigns.current_user)
    {:noreply, socket}
  end

  @impl true
  def handle_event("guess_word", %{"word" => word}, socket) do
    cond do
      word == "" ->
        {:noreply, socket |> put_flash(:error, "Votre réponse ne peut pas être vide!")}
      String.contains?(word, " ") ->
        {:noreply, socket |> put_flash(:error, "Votre réponse doit être un seul mot!")}
      true ->
        Rienkun.GameServer.guess_word(socket.assigns.game.room, word)
        {:noreply, socket}
    end
  end
end

 defmodule RienkunWeb.LoginController do
   use RienkunWeb, :controller

   def index(conn, params) do
     conn
     |> assign(:name, get_session(conn, :name))
     |> assign(:room, Map.get(params, "room", get_session(conn, :room)))
     |> render("login.html")
   end

   def login(conn, %{"name" => name, "room" => room}) do
     if name != "" and room != "" do
       conn
       |> put_session(:name, name)
       |> put_session(:room, room)
       |> put_session(:player_id, :crypto.strong_rand_bytes(20) |> Base.encode64 |> binary_part(0, 20))
       |> redirect(to: Routes.game_path(conn, :game, room))
     else
       conn
       |> put_flash(:error, "Veuillez entrer un nom et une salle.")
       |> redirect(to: Routes.login_path(conn, :index))
     end
   end
 end

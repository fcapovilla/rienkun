 defmodule RienkunWeb.LoginController do
   use RienkunWeb, :controller

   def index(conn, _params) do
     render(conn, "login.html")
   end

   def login(conn, %{"name" => name}) do
     if name != "" do
       conn
       |> put_session(:name, name)
       |> put_session(:player_id, :crypto.strong_rand_bytes(20) |> Base.encode64 |> binary_part(0, 20))
       |> redirect(to: Routes.game_path(conn, :game))
     else
       conn
       |> put_flash(:error, "Veuillez entrer un nom.")
       |> redirect(to: Routes.login_path(conn, :index))
     end
   end
 end

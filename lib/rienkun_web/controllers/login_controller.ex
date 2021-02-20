 defmodule RienkunWeb.LoginController do
   use RienkunWeb, :controller

   def index(conn, params) do
     room = (Map.get(params, "room", get_session(conn, :room)) || "") |> String.trim() |> String.slice(0..50)

     conn
     |> assign(:name, get_session(conn, :name))
     |> assign(:room, room)
     |> render("login.html")
   end

   def login(conn, %{"name" => name, "room" => room} = params) do
     name = name |> String.trim() |> String.slice(0..50)
     room = room |> String.trim() |> String.slice(0..50)

     if name != "" and room != "" do
       if !Rienkun.GameServer.get_pid(room) do
         Rienkun.GameSupervisor.start_game(room)

         if params["custom_words"] and params["custom_words"].path do
           words = File.read!(params["custom_words"].path) |> String.split("\n")
           Rienkun.GameServer.set_custom_words(room, words)
         end
       end

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

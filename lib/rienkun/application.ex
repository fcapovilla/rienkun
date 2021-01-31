defmodule Rienkun.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RienkunWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Rienkun.PubSub},
      RienkunWeb.Presence,
      # Start the Endpoint (http/https)
      RienkunWeb.Endpoint,
      Rienkun.GameServer,
      # Start a worker by calling: Rienkun.Worker.start_link(arg)
      # {Rienkun.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rienkun.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    RienkunWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

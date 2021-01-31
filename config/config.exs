# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :rienkun, RienkunWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "O8B4sQrauALtb+mGTxweVFWVNiL3ru5C0BUcA3d9ZIaaXt7493HWIMj1o4CrSaRZ",
  render_errors: [view: RienkunWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Rienkun.PubSub,
  live_view: [signing_salt: "Hhkhy8uu"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

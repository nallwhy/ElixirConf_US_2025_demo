# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :andrew, ash_domains: [Andrew.Domain.Invoicing], ecto_repos: [Andrew.Repo]

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :attributes,
        :relationships,
        :actions,
        :resource,
        :calculations,
        :aggregates,
        :validations,
        :changes,
        :preparations,
        :code_interface,
        :policies,
        :pub_sub,
        :identities,
        :multitenancy,
        :sqlite
      ]
    ],
    "Ash.Domain": [
      section_order: [:resources, :tools, :policies, :authorization, :domain, :execution]
    ]
  ]

config :andrew,
  ecto_repos: [Andrew.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :andrew, AndrewWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AndrewWeb.ErrorHTML, json: AndrewWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Andrew.PubSub,
  live_view: [signing_salt: "rXJGb3lU"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.0",
  andrew: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  andrew: [
    args: ~w[
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ],
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

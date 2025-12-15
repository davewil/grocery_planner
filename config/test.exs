import Config
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true, debug_errors: true

config :ash_json_api, :log_errors?, true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :grocery_planner, GroceryPlanner.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "grocery_planner_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  installed_extensions: ["citext"]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :grocery_planner, GroceryPlannerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "s8zJzQvNjJgEwjYWXTHQySZSImIIxLNuylOog5rmmfFBSc6NfuSSLbWYypJCgXmG",
  server: false

# In test we don't send emails
config :grocery_planner, GroceryPlanner.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :grocery_planner, :the_meal_db_client, GroceryPlanner.External.TheMealDB
config :grocery_planner, :the_meal_db_opts, plug: {Req.Test, GroceryPlanner.External.TheMealDB}

config :bcrypt_elixir, log_rounds: 1

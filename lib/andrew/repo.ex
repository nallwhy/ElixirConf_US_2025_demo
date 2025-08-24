defmodule Andrew.Repo do
  use Ecto.Repo,
    otp_app: :andrew,
    adapter: Ecto.Adapters.SQLite3
end

defmodule DpulCollections.FiggyRepo do
  use Ecto.Repo,
    otp_app: :dpul_collections,
    adapter: Ecto.Adapters.Postgres,
    read_only: true
end

defmodule DpulCollections.FiggyRepo do
  use Ecto.Repo,
    otp_app: :dpul_collections,
    adapter: Ecto.Adapters.Postgres
end

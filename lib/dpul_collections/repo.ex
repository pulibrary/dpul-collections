defmodule DpulCollections.Repo do
  use Ecto.Repo,
    otp_app: :dpul_collections,
    adapter: Ecto.Adapters.Postgres

  if Mix.env() in [:dev, :test] do
    @spec truncate(Ecto.Schema.t()) :: :ok
    def truncate(schema) do
      table_name = schema.__schema__(:source)
      query("TRUNCATE #{table_name}", [])
      :ok
    end
  end
end

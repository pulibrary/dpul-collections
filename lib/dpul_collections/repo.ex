defmodule DpulCollections.Repo do
  use Ecto.Repo,
    otp_app: :dpul_collections,
    adapter: Ecto.Adapters.Postgres

  def truncate_all() do
    {:ok, %{rows: table_names}} =
      __MODULE__.query(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name != 'schema_migrations'"
      )

    # Flatten the list of lists into a single list of table names
    table_names = Enum.map(table_names, fn [table_name] -> table_name end)

    # Construct and execute TRUNCATE statements for each table
    Enum.each(table_names, fn table_name ->
      __MODULE__.query!("TRUNCATE TABLE #{table_name} RESTART IDENTITY CASCADE")
    end)
  end
end

defmodule DpulCollections.Repo.Migrations.CreateDurableServerObjects do
  use Ecto.Migration

  def change do
    create table(:durable_server_objects, primary_key: false) do
      add :key, :text, primary_key: true
      add :body, :map
      add :version, :bigint, null: false, default: 1

      timestamps(type: :utc_datetime_usec)
    end

    # Index for prefix-based listing (LIKE 'prefix%' queries)
    create index(:durable_server_objects, [:key], using: "btree")
  end
end

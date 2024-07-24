defmodule DpulCollections.Repo.Migrations.CreateHydrationCacheEntries do
  use Ecto.Migration

  def change do
    create table(:hydration_cache_entries) do
      add :data, :binary
      add :cache_version, :integer
      add :record_id, :string
      add :source_cache_order, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end

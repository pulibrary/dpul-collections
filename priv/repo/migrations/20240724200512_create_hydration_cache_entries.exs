defmodule DpulCollections.Repo.Migrations.CreateFiggyHydrationCacheEntries do
  use Ecto.Migration

  def change do
    create table(:figgy_hydration_cache_entries) do
      add :data, :map
      add :cache_version, :integer
      add :record_id, :string
      add :source_cache_order, :utc_datetime_usec

      timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime_usec)
    end

    create(
      unique_index(
        :figgy_hydration_cache_entries,
        [:record_id, :cache_version],
        name: :figgy_hydration_record_id_cache_version_idx
      )
    )
  end
end

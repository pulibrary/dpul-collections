defmodule DpulCollections.Repo.Migrations.AddRelatedDataToHydrationCacheEntry do
  use Ecto.Migration

  def change do
    alter table(:figgy_hydration_cache_entries) do
      add :related_data, :jsonb, default: "{}"
    end

    execute(
      "CREATE INDEX figgy_hydration_related_data_idx ON figgy_hydration_cache_entries USING gin (related_data);"
    )
  end
end

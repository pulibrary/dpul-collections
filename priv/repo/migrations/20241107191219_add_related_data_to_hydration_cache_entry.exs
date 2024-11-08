defmodule DpulCollections.Repo.Migrations.AddRelatedDataToHydrationCacheEntry do
  use Ecto.Migration

  def change do
    alter table(:figgy_hydration_cache_entries) do
      add :related_data, :json, default: "{}"
    end
  end
end

defmodule DpulCollections.Repo.Migrations.RenameHydrationCacheEntries do
  use Ecto.Migration

  def change do
    rename table(:figgy_hydration_cache_entries), :data, to: :resource
    rename table(:figgy_hydration_cache_entries), to: table(:figgy_combined_resources)
  end
end

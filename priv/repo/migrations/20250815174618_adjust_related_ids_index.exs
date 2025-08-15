defmodule DpulCollections.Repo.Migrations.AdjustRelatedIdsIndex do
  use Ecto.Migration

  def change do
    drop index(:figgy_hydration_cache_entries, [:related_ids, :cache_version],
           name: :figgy_hydration_related_ids_cache_version_idx
         )
    create index(:figgy_hydration_cache_entries, [:related_ids], name: :figgy_hydration_related_ids_idx, using: "GIN")
    create index(:figgy_hydration_cache_entries, [:source_cache_order])
    create index(:figgy_hydration_cache_entries, [:cache_version, :source_cache_order])
  end
end

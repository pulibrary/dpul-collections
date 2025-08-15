defmodule DpulCollections.Repo.Migrations.AdjustRelatedIdsIndex do
  use Ecto.Migration

  def change do
    drop_if_exists index(:figgy_hydration_cache_entries, [:related_ids, :cache_version],
           name: :figgy_hydration_related_ids_cache_version_idx
         )

    create_if_not_exists index(:figgy_hydration_cache_entries, [:related_ids],
             name: :figgy_hydration_related_ids_idx,
             using: "GIN"
           )

    create_if_not_exists index(:figgy_hydration_cache_entries, [:source_cache_order])
    create_if_not_exists index(:figgy_hydration_cache_entries, [:cache_version, :source_cache_order])
  end
end

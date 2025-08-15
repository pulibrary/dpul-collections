defmodule DpulCollections.Repo.Migrations.AddRelatedIdsToHydrationCacheEntry do
  use Ecto.Migration

  def change do
    alter table(:figgy_hydration_cache_entries) do
      add :related_ids, {:array, :string}, default: []
    end

    create(
      index(
        :figgy_hydration_cache_entries,
        [:related_ids],
        name: :figgy_hydration_related_ids_idx,
        using: :gin
      )
    )
  end
end

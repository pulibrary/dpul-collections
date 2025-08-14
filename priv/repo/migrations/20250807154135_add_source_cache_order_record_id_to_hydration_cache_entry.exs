defmodule DpulCollections.Repo.Migrations.AddSourceCacheOrderRecordIdToHydrationCacheEntry do
  use Ecto.Migration

  def change do
    alter table(:figgy_hydration_cache_entries) do
      add :source_cache_order_record_id, :string
    end
  end
end

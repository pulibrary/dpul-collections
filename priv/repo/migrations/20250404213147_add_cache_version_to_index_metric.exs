defmodule DpulCollections.Repo.Migrations.AddCacheVersionToIndexMetric do
  use Ecto.Migration

  def change do
    alter table("index_metrics") do
      add :cache_version, :integer, default: 0
    end

    create index(:index_metrics, [:cache_version])
  end
end

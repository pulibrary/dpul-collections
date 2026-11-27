defmodule DpulCollections.Repo.Migrations.GeorefQueueRounds do
  use Ecto.Migration

  def change do
    # street renames learned from an atlas's fitted sheets (Georef.Renames)
    alter table(:georef_atlases) do
      add :renames, :map, default: %{}
    end

    # round 2: declined canvases again, with the learned renames
    alter table(:georef_jobs) do
      add :round, :integer, null: false, default: 1
    end

    drop unique_index(:georef_jobs, [:atlas_id, :canvas_index])
    create unique_index(:georef_jobs, [:atlas_id, :canvas_index, :round])
  end
end

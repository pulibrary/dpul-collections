defmodule DpulCollections.Repo.Migrations.CreateGeorefContributions do
  use Ecto.Migration

  def change do
    create table(:georef_contributions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :id, on_delete: :nilify_all)
      add :atlas_id, :string, null: false
      add :atlas_label, :text
      add :canvas_id, :text, null: false
      add :canvas_label, :string
      add :part, :integer, null: false, default: 1
      # placed | cannot
      add :verdict, :string, null: false
      # auto (the browser's own fit) | adjusted (moved by hand, then saved)
      add :method, :string
      # {a, b, tx, ty}: world metres (local projection) from canvas pixels
      add :transform, :map
      add :projection, :map
      # what the contributor's browser measured, and on what hardware
      add :scores, :map
      add :compute, :map
      # the IIIF Georeference Annotation for this part
      add :annotation, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:georef_contributions, [:user_id])
    create index(:georef_contributions, [:atlas_id, :canvas_id, :part])
  end
end

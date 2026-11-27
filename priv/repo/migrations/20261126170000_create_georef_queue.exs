defmodule DpulCollections.Repo.Migrations.CreateGeorefQueue do
  use Ecto.Migration

  def change do
    # An atlas queued for volunteers: what the server prepares (manifest, the
    # town's search box) so browsers can do the georeferencing.
    create table(:georef_atlases, primary_key: false) do
      add :id, :string, primary_key: true
      add :manifest, :text, null: false
      add :label, :text
      add :bbox, {:array, :float}
      add :exclude_keys, {:array, :string}, default: []
      # [%{id, label, service, width, height}]
      add :canvases, {:array, :map}, default: []

      timestamps(type: :utc_datetime_usec)
    end

    # One canvas to georeference, picked up by a volunteer's browser.
    create table(:georef_jobs, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :atlas_id, references(:georef_atlases, type: :string, on_delete: :delete_all),
        null: false

      add :canvas_index, :integer, null: false
      # queued | claimed | done | failed
      add :status, :string, null: false, default: "queued"
      add :attempts, :integer, null: false, default: 0
      add :claimed_at, :utc_datetime_usec
      # the browser tab working on it, and who it belongs to (nil: not signed in)
      add :worker, :string
      add :user_id, references(:users, type: :id, on_delete: :nilify_all)
      add :result, :map
      add :error, :text
      add :finished_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:georef_jobs, [:atlas_id, :canvas_index])
    create index(:georef_jobs, [:status, :inserted_at])
    create index(:georef_jobs, [:user_id])
  end
end

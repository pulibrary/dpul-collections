defmodule DpulCollections.Repo.Migrations.CreateDistributedOcrTables do
  use Ecto.Migration

  def change do
    create table(:ocr_jobs) do
      add :image_url, :string, null: false
      add :manifest_url, :string
      add :manifest_label, :string, size: 3000
      add :page_label, :string, size: 3000
      add :mode, :string, null: false, default: "ocr"
      add :status, :string, null: false, default: "queued"
      add :claimed_by, :string
      add :claimed_at, :utc_datetime_usec
      add :lease_expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:ocr_jobs, [:image_url])
    create index(:ocr_jobs, [:status])

    create table(:ocr_results) do
      add :image_url, :string, null: false
      add :text, :text
      add :client_id, :string
      add :model, :string
      add :model_version, :string
      add :duration_ms, :integer
      add :manifest_url, :string
      add :manifest_label, :string, size: 3000
      add :page_label, :string, size: 3000
      add :ocr_job_id, references(:ocr_jobs, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:ocr_results, [:image_url])
    create index(:ocr_results, [:manifest_url])
  end
end

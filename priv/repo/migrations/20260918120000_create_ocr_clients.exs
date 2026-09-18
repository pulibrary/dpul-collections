defmodule DpulCollections.Repo.Migrations.CreateOcrClients do
  use Ecto.Migration

  def change do
    create table(:ocr_clients) do
      add :client_id, :string, null: false
      add :status, :string, null: false, default: "idle"
      add :image_url, :string
      add :manifest_label, :string, size: 3000
      add :page_label, :string
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:ocr_clients, [:client_id])
  end
end

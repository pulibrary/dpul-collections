defmodule DpulCollections.Repo.Migrations.CreateUserSetItems do
  use Ecto.Migration

  def change do
    create table(:user_set_items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :solr_id, :string
      add :set_id, references(:user_sets, type: :uuid, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_set_items, [:set_id])
    create unique_index(:user_set_items, [:set_id, :solr_id])
  end
end

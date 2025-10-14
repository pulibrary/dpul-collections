defmodule DpulCollections.Repo.Migrations.CreateUserSetItems do
  use Ecto.Migration

  def change do
    create table(:user_set_items) do
      add :solr_id, :string
      add :set_id, references(:user_sets, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:user_set_items, [:set_id])
  end
end

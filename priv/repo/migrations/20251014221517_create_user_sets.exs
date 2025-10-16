defmodule DpulCollections.Repo.Migrations.CreateUserSets do
  use Ecto.Migration

  def change do
    create table(:user_sets, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string
      add :description, :text
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_sets, [:user_id])
  end
end

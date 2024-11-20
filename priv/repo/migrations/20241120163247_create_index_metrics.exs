defmodule DpulCollections.Repo.Migrations.CreateIndexMetrics do
  use Ecto.Migration

  def change do
    create table(:index_metrics) do
      add :type, :string
      add :measurement_type, :string
      add :duration, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create index(:index_metrics, [:type])
    create index(:index_metrics, [:measurement_type])
  end
end

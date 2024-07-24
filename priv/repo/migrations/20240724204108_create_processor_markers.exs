defmodule DpulCollections.Repo.Migrations.CreateProcessorMarkers do
  use Ecto.Migration

  def change do
    create table(:processor_markers) do
      add :cache_location, :utc_datetime
      add :cache_version, :integer
      add :type, :string

      timestamps(type: :utc_datetime)
    end
  end
end

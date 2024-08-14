defmodule DpulCollections.IndexingPipeline.ProcessorMarker do
  use Ecto.Schema
  import Ecto.Changeset

  schema "processor_markers" do
    field :type, :string
    field :cache_location, :utc_datetime_usec
    field :cache_record_id, :string
    field :cache_version, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(processor_marker, attrs) do
    processor_marker
    |> cast(attrs, [:cache_location, :cache_version, :type])
    |> validate_required([:cache_location, :cache_version, :type])
  end
end

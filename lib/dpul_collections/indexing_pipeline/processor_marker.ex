defmodule DpulCollections.IndexingPipeline.ProcessorMarker do
  @type marker :: { DateTime.t(), String.t() }
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

  @spec compare(marker1 :: marker(), marker2 :: marker()) :: :gt | :lt | :eq
  def compare(marker1, marker1), do: :eq
  def compare({marker_date1, _marker_id1}, {marker_date2, _marker_id2}) when marker_date1 != marker_date2 do
    DateTime.compare(marker_date1, marker_date2)
  end
  def compare({marker_date1, marker_id1}, {marker_date1, marker_id2}) do
    cond do
      marker_id1 < marker_id2 -> :lt
      marker_id1 > marker_id2 -> :gt
    end
  end
end

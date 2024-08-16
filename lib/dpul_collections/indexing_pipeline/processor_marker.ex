defmodule DpulCollections.IndexingPipeline.ProcessorMarker do
  @type marker :: {DateTime.t(), String.t()}
  use Ecto.Schema
  import Ecto.Changeset
  alias DpulCollections.IndexingPipeline.FiggyResource

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

  def compare({marker_date1, _marker_id1}, {marker_date2, _marker_id2})
      when marker_date1 != marker_date2 do
    DateTime.compare(marker_date1, marker_date2)
  end

  def compare({marker_date1, marker_id1}, {marker_date1, marker_id2}) do
    cond do
      marker_id1 < marker_id2 -> :lt
      marker_id1 > marker_id2 -> :gt
    end
  end

  @spec to_marker(%__MODULE__{}) :: marker()
  @doc """
  Converts ProcessorMarker struct to a marker tuple.
  """
  def to_marker(%__MODULE__{
        cache_location: cache_location,
        cache_record_id: cache_record_id
      }) do
    {cache_location, cache_record_id}
  end

  def to_marker(nil), do: nil
  @spec to_marker(%FiggyResource{}) :: marker()
  def to_marker(%FiggyResource{updated_at: updated_at, id: id}) do
    {updated_at, id}
  end

  @spec to_marker(%Broadway.Message{}) :: marker()
  def to_marker(%Broadway.Message{data: data}) do
    to_marker(data)
  end
end

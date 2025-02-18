defmodule DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker do
  @type t :: %__MODULE__{id: String.t(), timestamp: UTCDateTime}
  defstruct [:id, :timestamp]

  alias DpulCollections.IndexingPipeline.ProcessorMarker

  alias DpulCollections.IndexingPipeline.Figgy.{
    TransformationCacheEntry,
    HydrationCacheEntry,
    Resource
  }

  @spec from(%ProcessorMarker{}) :: t()
  @doc """
  Converts ProcessorMarker struct to a marker tuple.
  """
  def from(%ProcessorMarker{
        cache_location: cache_location,
        cache_record_id: cache_record_id
      }) do
    %__MODULE__{timestamp: cache_location, id: cache_record_id}
  end

  def from(nil), do: nil

  @spec from(%TransformationCacheEntry{}) :: t()
  def from(%TransformationCacheEntry{cache_order: timestamp, record_id: id}) do
    %__MODULE__{timestamp: timestamp, id: id}
  end

  @spec from(%Resource{}) :: t()
  def from(%Resource{
        updated_at: updated_at,
        internal_resource: "DeletionMarker",
        metadata: %{"resource_id" => [%{"id" => id}]}
      }) do
    %__MODULE__{timestamp: updated_at, id: id}
  end

  def from(%Resource{updated_at: updated_at, id: id}) do
    %__MODULE__{timestamp: updated_at, id: id}
  end

  @spec from(%HydrationCacheEntry{}) :: t()
  def from(%HydrationCacheEntry{cache_order: timestamp, record_id: id}) do
    %__MODULE__{timestamp: timestamp, id: id}
  end

  @spec from(%Broadway.Message{}) :: t()
  def from(%Broadway.Message{data: %{marker: marker}}) do
    marker
  end

  def from(%Broadway.Message{data: data}) do
    from(data)
  end

  def from(marker = %__MODULE__{}), do: marker

  @spec compare(marker1 :: t(), marker2 :: t()) :: :gt | :lt | :eq
  def compare(marker1, marker1), do: :eq

  def compare(%__MODULE__{timestamp: marker_date1}, %__MODULE__{timestamp: marker_date2})
      when marker_date1 != marker_date2 do
    DateTime.compare(marker_date1, marker_date2)
  end

  def compare(%__MODULE__{timestamp: marker_date1, id: marker_id1}, %__MODULE__{
        timestamp: marker_date1,
        id: marker_id2
      }) do
    cond do
      marker_id1 < marker_id2 -> :lt
      marker_id1 > marker_id2 -> :gt
    end
  end
end

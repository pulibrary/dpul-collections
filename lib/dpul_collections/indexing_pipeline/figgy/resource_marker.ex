defmodule DpulCollections.IndexingPipeline.Figgy.ResourceMarker do
  @type t :: %__MODULE__{id: String.t(), timestamp: UTCDateTime}
  defstruct [:id, :timestamp]

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.ProcessorMarker

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

  @spec from(%Figgy.Resource{}) :: t()
  def from(%Figgy.Resource{updated_at: updated_at, id: id}) do
    %__MODULE__{timestamp: updated_at, id: id}
  end

  @spec from(%Broadway.Message{}) :: t()
  def from(%Broadway.Message{data: data}) do
    from(data)
  end

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

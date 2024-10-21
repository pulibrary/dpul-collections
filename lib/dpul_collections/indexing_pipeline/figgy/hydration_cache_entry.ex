defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "figgy_hydration_cache_entries" do
    field :data, :map
    field :cache_version, :integer
    field :record_id, :string
    field :source_cache_order, :utc_datetime_usec

    timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(hydration_cache_entry, attrs) do
    hydration_cache_entry
    |> cast(attrs, [:data, :cache_version, :record_id, :source_cache_order])
    |> validate_required([:data, :cache_version, :record_id, :source_cache_order])
  end

  @spec to_solr_document(%__MODULE__{}) :: %{}
  def to_solr_document(hydration_cache_entry) do
    %{record_id: id} = hydration_cache_entry
    %{data: %{"metadata" => metadata}} = hydration_cache_entry

    %{
      id: id,
      title_ss: get_in(metadata, ["title"]),
      description_txtm: get_in(metadata, ["description"]),
      years_is: extract_years(metadata),
      display_date_s: format_date(metadata),
      page_count_i: page_count(metadata)
    }
  end

  defp page_count(%{"member_ids" => member_ids}) when is_list(member_ids) do
    member_ids |> length
  end

  defp page_count(_) do
    0
  end

  defp extract_years(%{"date_range" => [%{"start" => [start_year], "end" => [end_year]}]}) do
    Enum.to_list(String.to_integer(start_year)..String.to_integer(end_year))
  end

  defp extract_years(%{"date_created" => []}) do
    nil
  end

  # This will be single value from figgy, stored as an array.
  # If somehow we get more than 1 value, just take the first
  # It goes into a multi-valued index field, so keep it looking that way
  defp extract_years(%{"date_created" => [date | _tail]}) do
    [String.to_integer(date)]
  end

  defp extract_years(%{}) do
    # there's no date_created value
    nil
  end

  defp format_date(%{
         "date_range" => [%{"start" => [start_year], "end" => [end_year], "approximate" => "1"}]
       }) do
    "#{start_year} - #{end_year} (approximate)"
  end

  defp format_date(%{"date_range" => [%{"start" => [start_year], "end" => [end_year]}]}) do
    "#{start_year} - #{end_year}"
  end

  defp format_date(%{"date_created" => [date | _tail]}) do
    date
  end

  defp format_date(%{"date_created" => []}) do
    nil
  end

  defp format_date(%{}) do
    # there's no date_created value
    nil
  end
end

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
    %{data: %{"metadata" => metadata = %{"title" => title}}} = hydration_cache_entry
    description = get_in(metadata, ["description"])
    years = extract_years(metadata)
    display_date = format_date(metadata)

    %{
      id: id,
      title_ss: title,
      description_txtm: description,
      years_is: years,
      display_date_ss: display_date
    }
  end

  defp extract_years(%{"date_range" => [%{"start" => [start_year], "end" => [end_year]}]}) do
    Enum.to_list(String.to_integer(start_year)..String.to_integer(end_year))
  end

  defp extract_years(%{"date_created" => []}) do
    nil
  end

  defp extract_years(%{"date_created" => date}) do
    Enum.map(date, &String.to_integer/1)
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

  defp format_date(%{"date_created" => [date]}) do
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

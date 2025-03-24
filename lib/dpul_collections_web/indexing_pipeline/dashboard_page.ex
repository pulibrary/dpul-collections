defmodule DpulCollectionsWeb.IndexingPipeline.DashboardPage do
  alias DpulCollections.IndexingPipeline.Figgy.IndexingProducerSource
  alias DpulCollections.IndexingPipeline.Figgy.TransformationProducerSource
  alias DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource
  alias DpulCollections.IndexMetricsTracker
  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        hydration_times: IndexMetricsTracker.processor_durations(HydrationProducerSource),
        transformation_times:
          IndexMetricsTracker.processor_durations(TransformationProducerSource),
        indexing_times: IndexMetricsTracker.processor_durations(IndexingProducerSource)
      )

    {:ok, socket, temporary_assigns: [item_count: nil]}
  end

  @impl true
  def menu_link(_, _) do
    {:ok, "Index Metrics"}
  end

  defp hydration_times(_params, _node) do
    hydration_times =
      IndexMetricsTracker.processor_durations(HydrationProducerSource)
      |> Enum.map(&Map.from_struct/1)

    {hydration_times, length(hydration_times)}
  end

  defp transformation_times(_params, _node) do
    transformation_times =
      IndexMetricsTracker.processor_durations(TransformationProducerSource)
      |> Enum.map(&Map.from_struct/1)

    {transformation_times, length(transformation_times)}
  end

  defp indexing_times(_params, _node) do
    indexing_times =
      IndexMetricsTracker.processor_durations(IndexingProducerSource)
      |> Enum.map(&Map.from_struct/1)

    {indexing_times, length(indexing_times)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_table
      id="hydration-table"
      dom_id="hydration-table"
      page={@page}
      limit={nil}
      title="Hydration Metric Times (1 hour .. 2 days)"
      row_fetcher={&hydration_times/2}
      rows_name="metrics"
    >
      <:col field={:updated_at} sortable={:desc} />
      <:col :let={record} field={:duration} header="Duration (hh:mm:ss)">
        {to_hh_mm_ss(record.duration)}
      </:col>
      <:col field={:records_acked} header="Record Count" />
      <:col :let={record} field={:per_second} header="Records per Second">
        {per_second(record)}
      </:col>
    </.live_table>
    <.live_table
      id="transformation-table"
      dom_id="transformation-table"
      page={@page}
      limit={nil}
      title="Transformation Metric Times (30 minutes .. 2 hours)"
      row_fetcher={&transformation_times/2}
      rows_name="metrics"
    >
      <:col field={:updated_at} sortable={:desc} />
      <:col :let={record} field={:duration} header="Duration (hh:mm:ss)">
        {to_hh_mm_ss(record.duration)}
      </:col>
      <:col field={:records_acked} header="Record Count" />
      <:col :let={record} field={:per_second} header="Records per Second">
        {per_second(record)}
      </:col>
    </.live_table>
    <.live_table
      id="indexing-table"
      dom_id="indexing-table"
      page={@page}
      limit={nil}
      title="Indexing Metric Times (10 minutes .. 1 hour)"
      row_fetcher={&indexing_times/2}
      rows_name="metrics"
    >
      <:col field={:updated_at} sortable={:desc} />
      <:col :let={record} field={:duration} header="Duration (hh:mm:ss)">
        {to_hh_mm_ss(record.duration)}
      </:col>
      <:col field={:records_acked} header="Record Count" />
      <:col :let={record} field={:per_second} header="Records per Second">
        {per_second(record)}
      </:col>
    </.live_table>
    """
  end

  defp per_second(%{duration: 0, records_acked: records_acked}) do
    records_acked
  end

  defp per_second(%{duration: duration, records_acked: records_acked}) do
    records_acked / duration
  end

  # Pulled from
  # https://nickjanetakis.com/blog/formatting-seconds-into-hh-mm-ss-with-elixir-and-python
  # and modified to be consistently hh:mm:ss
  defp to_hh_mm_ss(0), do: "00:00:00"

  defp to_hh_mm_ss(seconds) do
    units = [3600, 60, 1]
    # Returns a list of how many hours, minutes, and seconds there are, reducing
    # the total seconds by that amount if it's greater than 1.
    t =
      Enum.map_reduce(units, seconds, fn unit, val -> {div(val, unit), rem(val, unit)} end)
      |> elem(0)

    Enum.map_join(t, ":", fn x -> x |> Integer.to_string() |> String.pad_leading(2, "0") end)
  end
end

defmodule DpulCollections.IndexingPipeline.DashboardPage do
  alias DpulCollections.IndexingPipeline.Figgy.IndexingProducerSource
  alias DpulCollections.IndexingPipeline.Figgy.TransformationProducerSource
  alias DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource
  alias DpulCollections.IndexMetricsTracker
  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        hydration_times: IndexMetricsTracker.index_times(HydrationProducerSource),
        transformation_times: IndexMetricsTracker.index_times(TransformationProducerSource),
        indexing_times: IndexMetricsTracker.index_times(IndexingProducerSource)
      )

    {:ok, socket, temporary_assigns: [item_count: nil]}
  end

  @impl true
  def menu_link(_, _) do
    {:ok, "Index Metrics"}
  end

  defp hydration_times(_params, _node) do
    hydration_times =
      IndexMetricsTracker.index_times(HydrationProducerSource)
      |> Enum.map(&Map.from_struct/1)

    {hydration_times, length(hydration_times)}
  end

  defp transformation_times(_params, _node) do
    transformation_times =
      IndexMetricsTracker.index_times(TransformationProducerSource)
      |> Enum.map(&Map.from_struct/1)

    {transformation_times, length(transformation_times)}
  end

  defp indexing_times(_params, _node) do
    indexing_times =
      IndexMetricsTracker.index_times(IndexingProducerSource)
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
      title="Hydration Metric Times (1 hour .. 2 days)"
      row_fetcher={&hydration_times/2}
      rows_name="metrics"
    >
      <:col field={:updated_at} sortable={:desc} />
      <:col field={:duration} header="Duration (s)" />
      <:col field={:records_acked} header="Record Count" />
      <:col :let={record} field={:per_second} header="Records per Second">
        <%= per_second(record) %>
      </:col>
    </.live_table>
    <.live_table
      id="transformation-table"
      dom_id="transformation-table"
      page={@page}
      title="Transformation Metric Times (30 minutes .. 2 hours)"
      row_fetcher={&transformation_times/2}
      rows_name="metrics"
    >
      <:col field={:updated_at} sortable={:desc} />
      <:col field={:duration} header="Duration (s)" />
      <:col field={:records_acked} header="Record Count" />
      <:col :let={record} field={:per_second} header="Records per Second">
        <%= per_second(record) %>
      </:col>
    </.live_table>
    <.live_table
      id="indexing-table"
      dom_id="indexing-table"
      page={@page}
      title="Indexing Metric Times (10 minutes .. 1 hour)"
      row_fetcher={&indexing_times/2}
      rows_name="metrics"
    >
      <:col field={:updated_at} sortable={:desc} />
      <:col field={:duration} header="Duration (s)" />
      <:col field={:records_acked} header="Record Count" />
      <:col :let={record} field={:per_second} header="Records per Second">
        <%= per_second(record) %>
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
end

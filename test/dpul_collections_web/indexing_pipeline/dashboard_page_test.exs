defmodule DpuLCollectionsWeb.IndexingPipeline.DashboardPageTest do
  alias DpulCollections.IndexingPipeline.Figgy.IndexingProducerSource
  alias DpulCollections.IndexingPipeline.Figgy.TransformationProducerSource
  alias DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource
  alias DpulCollections.IndexingPipeline.Metrics
  alias DpulCollections.IndexingPipeline
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint

  test "GET /dev/dashboard/index_metrics", %{conn: conn} do
    Metrics.create_index_metric(%{
      type: HydrationProducerSource.processor_marker_key(),
      measurement_type: "full_index",
      duration: 0,
      records_acked: 20,
      cache_version: 1
    })

    Metrics.create_index_metric(%{
      type: HydrationProducerSource.processor_marker_key(),
      measurement_type: "full_index",
      duration: 0,
      records_acked: 20,
      cache_version: 2
    })

    Metrics.create_index_metric(%{
      type: TransformationProducerSource.processor_marker_key(),
      measurement_type: "full_index",
      duration: 10,
      records_acked: 20,
      cache_version: 1
    })

    Metrics.create_index_metric(%{
      type: IndexingProducerSource.processor_marker_key(),
      measurement_type: "full_index",
      duration: 200,
      records_acked: 60,
      cache_version: 1
    })

    {marker1, marker2, _marker3} = FiggyTestFixtures.markers()

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_hydrator",
      cache_version: 0,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 0,
      cache_location: marker2.timestamp,
      cache_record_id: marker2.id
    })

    {:ok, view, html} =
      conn
      |> put_req_header("authorization", "Basic " <> Base.encode64("admin:test"))
      |> get(~p"/dev/dashboard/index_metrics")
      |> live

    assert html =~ "Hydration Metric Times"
    assert html =~ "Transformation Metric Times"
    assert html =~ "Indexing Metric Times"
    assert has_element?(view, "td.hydration-table-cache_version", "1")
    assert has_element?(view, "td.hydration-table-per_second", "20")
    assert has_element?(view, "td.hydration-table-duration", "00:00:00")
    assert has_element?(view, "td.transformation-table-cache_version", "1")
    assert has_element?(view, "td.transformation-table-per_second", "2")
    assert has_element?(view, "td.transformation-table-duration", "00:00:10")
    assert has_element?(view, "td.indexing-table-cache_version", "1")
    assert has_element?(view, "td.indexing-table-per_second", "0.3")
    assert has_element?(view, "td.indexing-table-duration", "00:03:20")
    assert html =~ "figgy_hydrator marker"
    assert html =~ "figgy_indexer marker"
    assert has_element?(view, "div.fields-card", marker1.id)
    assert has_element?(view, "div.fields-card", marker2.id)
  end
end

defmodule DpulCollections.PromEx.Plugins.IndexingPipelineTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker

  def assert_query_received do
    # Pulled from
    # https://github.com/akoutmos/prom_ex/blob/master/test/prom_ex/plugins/ecto_test.exs as an example.
    events =
      DpulCollections.PromEx
      |> PromEx.get_metrics()
      |> String.split("\n", trim: true)
      |> Enum.sort()

    assert events |> hd ==
             "# HELP dpul_collections_indexing_pipeline_query_duration_milliseconds Time for query to return"
  end

  describe "IndexingPipeline telemetry" do
    test "get_figgy_resource! is observable" do
      IndexingPipeline.get_figgy_resource!("8b0631b7-e1e4-49c2-904f-cd3141167a80")

      assert_query_received()
    end

    test "get_figgy_parents() is observable" do
      IndexingPipeline.get_figgy_parents("8b0631b7-e1e4-49c2-904f-cd3141167a80")

      assert_query_received()
    end

    test "get_related_hydration_cache_record_ids!() is observable" do
      IndexingPipeline.get_related_hydration_cache_record_ids!(
        "8b0631b7-e1e4-49c2-904f-cd3141167a80",
        ~U[1018-03-09 20:19:33.414040Z],
        0
      )

      assert_query_received()
    end

    test "get_figgy_parents()" do
      IndexingPipeline.get_figgy_parents("8b0631b7-e1e4-49c2-904f-cd3141167a80")

      assert_query_received()
    end

    test "get_figgy_resources()" do
      IndexingPipeline.get_figgy_resources(["8b0631b7-e1e4-49c2-904f-cd3141167a80"])

      assert_query_received()
    end

    test "get_figgy_resources_since!()" do
      # Calling the function with a marker
      fabricated_marker = %CacheEntryMarker{
        timestamp: ~U[1018-03-09 20:19:33.414040Z],
        id: "00000000-0000-0000-0000-000000000000"
      }

      IndexingPipeline.get_figgy_resources_since!(fabricated_marker, 1)

      assert_query_received()
    end
  end
end

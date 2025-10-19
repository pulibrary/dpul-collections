defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  alias DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource
  use DpulCollections.DataCase

  alias DpulCollections.Repo
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.{IndexingPipeline, Solr, IndexMetricsTracker}
  import SolrTestSupport

  setup do
    Solr.delete_all(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  @tag sandbox: false
  test "a full pipeline run of all 3 stages, then re-run of each stage" do
    # Start the figgy pipeline in a way that mimics how it is started in
    # dev and prod (slightly simplified)
    cache_version = 1

    {:ok, tracker_pid} = GenServer.start_link(AckTracker, self())

    # Create an index record to be deleted since it has zero members.
    DpulCollections.Solr.add(
      SolrTestSupport.mock_solr_documents(1)
      |> hd
      |> Map.put(:id, "f134f41f-63c5-4fdf-b801-0774e3bc3b2d")
    )

    # Pre-index records for testing deletes. DeletionMarkers in the test Figgy
    # database do not have related resources. We need to add the resources so we
    # can test that they get deleted.
    records_to_be_deleted =
      FiggyTestSupport.deletion_markers()
      |> FiggyTestFixtures.resources_from_deletion_markers()
      |> Enum.map(&FiggyTestSupport.index_record/1)

    children = [
      {Figgy.IndexingConsumer,
       cache_version: cache_version, batch_size: 50, solr_index: active_collection()},
      {Figgy.TransformationConsumer, cache_version: cache_version, batch_size: 50},
      {Figgy.HydrationConsumer, cache_version: cache_version, batch_size: 50}
    ]

    FiggyTestSupport.make_broadway_parallel()

    test_pid = self()

    :ok =
      :telemetry.attach(
        "hydration-full-run",
        [:dpulc, :indexing_pipeline, :hydrator, :time_to_poll],
        fn _, measurements, _, _ ->
          send(test_pid, {:hydrator_time_to_poll_hit, measurements})
        end,
        nil
      )

    # When we run tests with --repeat-until-failure the above attachment fails
    # on the second run if we haven't detached it.
    on_exit(fn -> :telemetry.detach("hydration-full-run") end)

    AckTracker.reset_count!(tracker_pid)

    Enum.each(children, fn child ->
      start_supervised(child)
    end)

    AckTracker.wait_for_pipeline_finished(tracker_pid)

    # The hydrator pulled all ephemera folders, terms, deletion markers and
    # removed the hydration cache markers for the deletion marker deleted resource. It also has the one ephemera project.
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() + 1 == entry_count

    # The transformer processed ephemera folders and deletion markers
    # removed the transformation cache markers for the deletion marker deleted resource.
    transformation_cache_entry_count = Repo.aggregate(Figgy.TransformationCacheEntry, :count)
    deletion_marker_count = FiggyTestSupport.deletion_marker_count()
    total_transformed_count = FiggyTestSupport.ephemera_folder_count() + deletion_marker_count + 1

    # Empty resources are resources with no image file sets
    empty_resource_count = 1

    assert total_transformed_count == transformation_cache_entry_count

    # indexed all the documents and deleted the extra record solr doc
    assert Solr.document_count() ==
             transformation_cache_entry_count - deletion_marker_count - empty_resource_count

    # Ensure that deleted records from deletion markers are removed from Solr
    Enum.each(records_to_be_deleted, fn record ->
      assert Solr.find_by_id(record[:id]) == nil
    end)

    # Ensure that the processor markers have the correct cache version
    hydration_processor_marker = IndexingPipeline.get_processor_marker!("figgy_hydrator", 1)

    transformation_processor_marker =
      IndexingPipeline.get_processor_marker!("figgy_transformer", 1)

    indexing_processor_marker = IndexingPipeline.get_processor_marker!("figgy_indexer", 1)
    assert hydration_processor_marker.cache_version == 1
    assert transformation_processor_marker.cache_version == 1
    assert indexing_processor_marker.cache_version == 1

    # Reindex Test
    latest_document = Solr.latest_document()

    transformation_entry =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    AckTracker.reset_count!(tracker_pid)

    Figgy.IndexingConsumer.start_over!(cache_version)

    AckTracker.wait_for_indexer(tracker_pid, 1)

    latest_document_again = Solr.latest_document()

    # Make sure it got reindexed
    assert latest_document["_version_"] != latest_document_again["_version_"]
    # Make sure we didn't add another one
    assert Solr.document_count() ==
             transformation_cache_entry_count - deletion_marker_count - empty_resource_count

    # transformation entries weren't updated
    transformation_entry_again =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    assert transformation_entry.cache_order == transformation_entry_again.cache_order

    # Retransformation Test
    latest_document = Solr.latest_document()

    transformation_entry =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    hydration_entry = Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    AckTracker.reset_count!(tracker_pid)

    Figgy.TransformationConsumer.start_over!(cache_version)

    tracker_pid
    |> AckTracker.wait_for_transformer(1)
    |> AckTracker.wait_for_indexer(1)

    Repo.aggregate(Figgy.TransformationCacheEntry, :count)

    # transformation entries were updated
    transformation_entry_again =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    assert transformation_entry.cache_order != transformation_entry_again.cache_order

    # hydration entries weren't updated
    hydration_entry_again =
      Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    assert hydration_entry.cache_order == hydration_entry_again.cache_order

    # Rehydration Test
    latest_document = Solr.latest_document()
    hydration_entry = Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    AckTracker.reset_count!(tracker_pid)

    Figgy.HydrationConsumer.start_over!(cache_version)

    AckTracker.wait_for_pipeline_finished(tracker_pid)

    hydration_entry_again =
      Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    assert hydration_entry.cache_order != hydration_entry_again.cache_order

    # Ensure metrics are being sent.
    assert_receive {:hydrator_time_to_poll_hit, %{duration: _}}, 500
    [hydration_metric_1 | _] = IndexMetricsTracker.processor_durations(HydrationProducerSource)
    assert hydration_metric_1.duration > 0
  end

  describe "an Ephemera Folder with a parent EphemeraBox" do
    test "indexes expected fields" do
      {hydrator, transformer, indexer, document} =
        FiggyTestSupport.index_record_id("26713a31-d615-49fd-adfc-93770b4f66b3")

      hydrator |> Broadway.stop(:normal)
      transformer |> Broadway.stop(:normal)
      indexer |> Broadway.stop(:normal)

      document["description_txtm"] |> dbg
      assert document["title_txtm"] == ["Ali Bagheri"]
      # Language Detection
      assert document["title_txtm_de"] == ["Ali Bagheri"]
      # Copy Field
      assert document["title_ss"] == ["Ali Bagheri"]
      # Description
      assert %{"description_txtm" => [first_description | _tail]} = document
      assert first_description |> String.starts_with?("Asra-Panahi") == true
      # Language detection
      assert %{"description_txtm_en" => [first_description | _tail]} = document
      assert first_description |> String.starts_with?("Asra-Panahi") == true
      assert %{"detectlang_ss" => ["de", "en"]} = document

      # Date fields
      assert document["years_is"] == [2022]
      assert document["display_date_s"] == "2022"

      # Controlled Vocabulary
      assert document["genre_txt_sort"] == ["Ephemera"]
      assert document["geo_subject_txt_sort"] == ["Iran"]
      assert document["geographic_origin_txt_sort"] == ["Iran"]
      assert document["language_txt_sort"] == ["Persian"]

      assert document["subject_txt_sort"] == [
               "Arts",
               "Arts--Political aspects",
               "Collective memory",
               "Freedom of expression",
               "Human rights",
               "Political violence",
               "Women's rights",
               "Minorities",
               "Civil society",
               "Democracy",
               "Revolutions"
             ]

      assert document["categories_txt_sort"] == [
               "Arts and culture",
               "Human and civil rights",
               "Minorities, ethnic and racial groups",
               "Politics and government"
             ]

      # Parent EphemeraProject
      assert document["ephemera_project_title_s"] == "Woman Life Freedom Movement: Iran 2022"
      assert document["ephemera_project_id_s"] == "2961c153-54ab-4c6a-b5cd-aa992f4c349b"

      # Image URLs
      assert [
               "https://iiif-cloud.princeton.edu/iiif/2/5e%2F24%2Faf%2F5e24aff45b2e4c9aaba3f05321d1c797%2Fintermediate_file"
               | _rest
             ] = document["image_service_urls_ss"]

      # Image Canvas IDs
      assert [
               "https://figgy.princeton.edu/concern/ephemera_folders/26713a31-d615-49fd-adfc-93770b4f66b3/manifest/canvas/f60ce0c9-57fc-4820-b70d-49d1f2b248f9"
               | _rest
             ] = document["image_canvas_ids_ss"]

      assert "https://iiif-cloud.princeton.edu/iiif/2/76%2F5e%2F4c%2F765e4c0ada4a468bad46cbbebec4242b%2Fintermediate_file" =
               document["primary_thumbnail_service_url_s"]

      assert 1.3454 = document["primary_thumbnail_h_w_ratio_f"]

      # IIIF Manifest URL
      assert "https://figgy.princeton.edu/concern/ephemera_folders/26713a31-d615-49fd-adfc-93770b4f66b3/manifest" =
               document["iiif_manifest_url_s"]

      # Resource has "none" pdf_type so will not index a pdf url
      assert document["pdf_url_s"] == nil
    end
  end

  describe "an Ephemera Folder with a parent EphemeraProject" do
    test "indexes expected fields" do
      {hydrator, transformer, indexer, document} =
        FiggyTestSupport.index_record_id("bfe04832-e57b-4ad9-939c-6ca5b466fa68")

      hydrator |> Broadway.stop(:normal)
      transformer |> Broadway.stop(:normal)
      indexer |> Broadway.stop(:normal)

      assert document["title_txtm"] == ["Guatemala information"]

      # Parent EphemeraProject
      assert document["ephemera_project_title_s"] ==
               "Guatemala News and Information Bureau Archive (1963-2000)"

      assert document["ephemera_project_id_s"] == "1e63fc3c-f41d-4512-9abc-8ed671a50261"
    end
  end

  describe "Ephemera Folder with a pdf type" do
    test "indexes expected fields" do
      {hydrator, transformer, indexer, document} =
        FiggyTestSupport.index_record_id("3da68e1c-06af-4d17-8603-fc73152e1ef7")

      hydrator |> Broadway.stop(:normal)
      transformer |> Broadway.stop(:normal)
      indexer |> Broadway.stop(:normal)

      assert document["pdf_url_s"] ==
               "https://figgy.example.com/concern/ephemera_folders/3da68e1c-06af-4d17-8603-fc73152e1ef7/pdf"
    end
  end

  describe "ephemera project" do
    test "indexes everything" do
      {hydrator, transformer, indexer, document} =
        FiggyTestSupport.index_record_id("f99af4de-fed4-4baa-82b1-6e857b230306")

      hydrator |> Broadway.stop(:normal)
      transformer |> Broadway.stop(:normal)
      indexer |> Broadway.stop(:normal)

      assert document["title_txtm"] == ["South Asian Ephemera"]
    end
  end
end

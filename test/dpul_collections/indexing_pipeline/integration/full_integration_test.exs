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

  def wait_for_index_completion() do
    transformation_cache_entries = IndexingPipeline.list_transformation_cache_entries() |> length
    ephemera_folder_count = FiggyTestSupport.ephemera_folder_count()

    # Count of resources to be deleted. In this test there is one added per
    # DeletionMarker. A transformation cache entry with the key `deleted: true`
    # stays in the transformation cache so the total number of records must take
    # this into account.
    deleted_resource_count = FiggyTestSupport.deletion_marker_count()
    total_records = ephemera_folder_count + deleted_resource_count
    # Empty resources are resources with no image file sets
    empty_resource_count = 1

    if System.get_env("DEBUG_INTEGRATION") do
      IO.puts(
        "tranformation_cache_entries: #{transformation_cache_entries} / total_records: #{total_records}"
      )
    end

    continue =
      if transformation_cache_entries == total_records do
        DpulCollections.Solr.commit(active_collection())
        solr_doc_count = DpulCollections.Solr.document_count()

        expected_doc_count =
          transformation_cache_entries - deleted_resource_count - empty_resource_count

        if System.get_env("DEBUG_INTEGRATION") do
          IO.puts("solr_count: #{solr_doc_count} / expected_doc_count: #{expected_doc_count}")
        end

        if solr_doc_count == expected_doc_count do
          true
        end
      end

    continue || (:timer.sleep(100) && wait_for_index_completion())
  end

  def wait_for_solr_version_change(doc = %{"_version_" => version, "id" => id}) do
    Solr.commit(active_collection())
    %{"_version_" => new_version} = Solr.find_by_id(id)

    if new_version == version do
      :timer.sleep(100) && wait_for_solr_version_change(doc)
    else
      true
    end
  end

  test "a full pipeline run of all 3 stages, then re-run of each stage" do
    # Start the figgy pipeline in a way that mimics how it is started in
    # dev and prod (slightly simplified)
    cache_version = 1

    # Pre-index records for testing deletes. DeletionMarkers in the test Figgy
    # database do not have related resources. We need to add the resources so we
    # can test that they get deleted.
    records_to_be_deleted =
      FiggyTestSupport.deletion_markers()
      |> FiggyTestFixtures.resources_from_deletion_markers()
      |> Enum.map(&FiggyTestSupport.index_record/1)

    children = [
      {Figgy.IndexingConsumer,
       cache_version: cache_version, batch_size: 50, write_collection: active_collection()},
      {Figgy.TransformationConsumer, cache_version: cache_version, batch_size: 50},
      {Figgy.HydrationConsumer, cache_version: cache_version, batch_size: 50}
    ]

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

    Enum.each(children, fn child ->
      start_supervised(child)
    end)

    task =
      Task.async(fn -> wait_for_index_completion() end)

    Task.await(task, 30000)

    # The hydrator pulled all ephemera folders, terms, deletion markers and
    # removed the hydration cache markers for the deletion marker deleted resource.
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() == entry_count

    # The transformer processed ephemera folders and deletion markers
    # removed the transformation cache markers for the deletion marker deleted resource.
    transformation_cache_entry_count = Repo.aggregate(Figgy.TransformationCacheEntry, :count)
    deletion_marker_count = FiggyTestSupport.deletion_marker_count()
    total_transformed_count = FiggyTestSupport.ephemera_folder_count() + deletion_marker_count

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

    Figgy.IndexingConsumer.start_over!(cache_version)

    task =
      Task.async(fn -> wait_for_solr_version_change(latest_document) end)

    Task.await(task, 30000)
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

    Figgy.TransformationConsumer.start_over!(cache_version)

    task =
      Task.async(fn -> wait_for_solr_version_change(latest_document) end)

    Task.await(task, 30000)

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

    Figgy.HydrationConsumer.start_over!(cache_version)

    task =
      Task.async(fn -> wait_for_solr_version_change(latest_document) end)

    Task.await(task, 30000)

    hydration_entry_again =
      Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    assert hydration_entry.cache_order != hydration_entry_again.cache_order

    # Ensure metrics are being sent.
    assert_receive {:hydrator_time_to_poll_hit, %{duration: _}}
    [hydration_metric_1 | _] = IndexMetricsTracker.processor_durations(HydrationProducerSource)
    assert hydration_metric_1.duration > 0
  end

  test "indexes expected fields" do
    {hydrator, transformer, indexer, document} =
      FiggyTestSupport.index_record_id("26713a31-d615-49fd-adfc-93770b4f66b3")

    hydrator |> Broadway.stop(:normal)
    transformer |> Broadway.stop(:normal)
    indexer |> Broadway.stop(:normal)

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
    assert document["genre_txtm"] == ["Ephemera"]
    assert document["geo_subject_txtm"] == ["Iran"]
    assert document["geographic_origin_txtm"] == ["Iran"]
    assert document["language_txtm"] == ["Persian"]

    assert document["subject_txtm"] == [
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

    # Image URLs
    assert [
             "https://iiif-cloud.princeton.edu/iiif/2/5e%2F24%2Faf%2F5e24aff45b2e4c9aaba3f05321d1c797%2Fintermediate_file"
             | _rest
           ] = document["image_service_urls_ss"]

    assert "https://iiif-cloud.princeton.edu/iiif/2/76%2F5e%2F4c%2F765e4c0ada4a468bad46cbbebec4242b%2Fintermediate_file" =
             document["primary_thumbnail_service_url_s"]

    # IIIF Manifest URL
    assert "https://figgy.princeton.edu/concern/ephemera_folders/26713a31-d615-49fd-adfc-93770b4f66b3/manifest" =
             document["iiif_manifest_url_s"]
  end
end

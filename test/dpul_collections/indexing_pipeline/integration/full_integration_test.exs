defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.Repo
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.{IndexingPipeline, Solr, Utilities}

  setup do
    Solr.delete_all()
    :ok
  end

  def wait_for_index_completion() do
    transformation_cache_entries = IndexingPipeline.list_transformation_cache_entries() |> length
    ephemera_folder_count = FiggyTestSupport.ephemera_folder_count()

    continue =
      if transformation_cache_entries == ephemera_folder_count do
        DpulCollections.Solr.commit()

        if DpulCollections.Solr.document_count() == transformation_cache_entries do
          true
        end
      end

    continue || (:timer.sleep(100) && wait_for_index_completion())
  end

  def wait_for_indexed_count(count) do
    DpulCollections.Solr.commit()

    continue =
      if DpulCollections.Solr.document_count() == count do
        true
      else
        false
      end

    continue || (:timer.sleep(100) && wait_for_indexed_count(count))
  end

  test "a full hydrator and transformer run" do
    # Start the figgy pipeline in a way that mimics how it is started in test and prod
    children = [
      {Figgy.IndexingConsumer, cache_version: 1, batch_size: 50},
      {Figgy.TransformationConsumer, cache_version: 1, batch_size: 50},
      {Figgy.HydrationConsumer, cache_version: 1, batch_size: 50}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: DpulCollections.TestSupervisor)

    task =
      Task.async(fn -> wait_for_index_completion() end)

    Task.await(task, 15000)

    # the hydrator pulled all ephemera folders and terms
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() == entry_count

    # the transformer only processes ephemera folders
    transformation_cache_entry_count = Repo.aggregate(Figgy.TransformationCacheEntry, :count)
    assert FiggyTestSupport.ephemera_folder_count() == transformation_cache_entry_count

    # indexed all the documents
    assert Solr.document_count() == transformation_cache_entry_count

    # Ensure that the processor markers have the correct cache version
    hydration_processor_marker = IndexingPipeline.get_processor_marker!("figgy_hydrator", 1)

    transformation_processor_marker =
      IndexingPipeline.get_processor_marker!("figgy_transformer", 1)

    indexing_processor_marker = IndexingPipeline.get_processor_marker!("figgy_indexer", 1)
    assert hydration_processor_marker.cache_version == 1
    assert transformation_processor_marker.cache_version == 1
    assert indexing_processor_marker.cache_version == 1

    # test reindexing
    # In normal use we wouldn't delete everything - how can we tell that a
    # reindex happened. How can we wait for it to be done?
    # We could get the version, then have a function that keeps trying to get it and see if the version changed.
    # TODO: The above.
    Repo.truncate(Figgy.TransformationCacheEntry)
    Repo.truncate(Figgy.HydrationCacheEntry)
    Solr.delete_all()
    assert Solr.document_count() == 0
    Figgy.IndexingConsumer.start_over!()

    task =
      Task.async(fn -> wait_for_index_completion() end)

    Task.await(task, 15000)
    assert Solr.document_count() == transformation_cache_entry_count

    Supervisor.stop(DpulCollections.TestSupervisor, :normal)
  end

  test "indexes description" do
    {hydrator, transformer, indexer, document} =
      FiggyTestSupport.index_record_id("26713a31-d615-49fd-adfc-93770b4f66b3")

    assert %{"description_txtm" => [first_description | _tail]} = document
    assert first_description |> String.starts_with?("Asra-Panahi") == true
    # Language detection
    assert %{"description_txtm_en" => [first_description | _tail]} = document
    assert first_description |> String.starts_with?("Asra-Panahi") == true
    assert %{"detectlang_ss" => ["en"]} = document

    hydrator |> Broadway.stop(:normal)
    transformer |> Broadway.stop(:normal)
    indexer |> Broadway.stop(:normal)
  end
end

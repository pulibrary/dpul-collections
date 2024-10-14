defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  alias ElixirLS.LanguageServer.Providers.CodeLens.Test
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

  def wait_for_solr_version_change(doc = %{"_version_" => version, "id" => id}) do
    Solr.commit()
    %{"_version_" => new_version} = Solr.find_by_id(id)

    if new_version == version do
      :timer.sleep(100) && wait_for_solr_version_change(doc)
    else
      true
    end
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

    # Reindex Test
    latest_document = Solr.latest_document()

    transformation_entry =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    Figgy.IndexingConsumer.start_over!()

    task =
      Task.async(fn -> wait_for_solr_version_change(latest_document) end)

    Task.await(task, 15000)
    latest_document_again = Solr.latest_document()
    # Make sure it got reindexed
    assert latest_document["_version_"] != latest_document_again["_version_"]
    # Make sure we didn't add another one
    assert Solr.document_count() == transformation_cache_entry_count
    # transformation entries weren't updated
    transformation_entry_again =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    assert transformation_entry.cache_order == transformation_entry_again.cache_order

    # Retransformation Test
    latest_document = Solr.latest_document()

    transformation_entry =
      Repo.get_by(Figgy.TransformationCacheEntry, record_id: latest_document["id"])

    hydration_entry = Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    Figgy.TransformationConsumer.start_over!()

    task =
      Task.async(fn -> wait_for_solr_version_change(latest_document) end)

    Task.await(task, 15000)

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

    Figgy.HydrationConsumer.start_over!()

    task =
      Task.async(fn -> wait_for_solr_version_change(latest_document) end)

    Task.await(task, 15000)

    hydration_entry_again =
      Repo.get_by(Figgy.HydrationCacheEntry, record_id: latest_document["id"])

    assert hydration_entry.cache_order != hydration_entry_again.cache_order

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

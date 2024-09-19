defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.{FiggyRepo, Repo}
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr

  setup do
    Solr.delete_all()
    :ok
  end

  def wait_for_index_completion() do
    transformer_cache_entries = IndexingPipeline.list_transformation_cache_entries() |> length
    ephemera_folder_count = FiggyTestSupport.ephemera_folder_count()

    continue =
      if transformer_cache_entries == ephemera_folder_count do
        DpulCollections.Solr.commit()

        if DpulCollections.Solr.document_count() == transformer_cache_entries do
          true
        end
      end

    continue || (:timer.sleep(100) && wait_for_index_completion())
  end

  test "a full hydrator and transformer run" do
    # Start the figgy producer
    {:ok, indexer} = Figgy.IndexingConsumer.start_link(batch_size: 50)
    {:ok, transformer} = Figgy.TransformationConsumer.start_link(batch_size: 50)
    {:ok, hydrator} = Figgy.HydrationConsumer.start_link(batch_size: 50)

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

    hydrator |> Broadway.stop(:normal)
    transformer |> Broadway.stop(:normal)
    indexer |> Broadway.stop(:normal)
  end
end

defmodule Mix.Tasks.ReindexDev do
  alias DpulCollections.IndexingPipeline.AckTracker

  @moduledoc "Mix task to reindex development: `mix help reindex_dev`. We have this so developers don't have to remember to commit Solr."
  use Mix.Task

  @shortdoc "Reindexes development and commits the index when it's done"
  def run(_) do
    Application.get_env(:dpul_collections, :environment_name)
    |> reindex()
  end

  defp reindex("dev") do
    # Start the app
    Mix.Task.run("app.start")
    # Start the pipeline - normally it only starts when the Phoenix server is
    # running.
    DpulCollections.Application.indexing_pipeline_children()
    |> Enum.each(fn child_spec ->
      Supervisor.start_child(DpulCollections.Supervisor, child_spec)
    end)

    # Start tracking the pipeline.
    {:ok, tracker_pid} = GenServer.start_link(AckTracker, self())
    # Restart the pipeline.
    DpulCollections.IndexingPipeline.Figgy.HydrationConsumer.start_over!(1)
    AckTracker.wait_for_pipeline_finished(tracker_pid)
    # Commit when it's done.
    DpulCollections.Solr.commit()
  end

  defp reindex(_), do: nil
end

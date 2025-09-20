defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumer.Constants do
  defmacro __using__(_) do
    quote do
      @update_record_types ["EphemeraFolder", "DeletionMarker"]
      @related_record_types ["EphemeraProject", "EphemeraBox", "EphemeraTerm", "FileSet"]
    end
  end
end

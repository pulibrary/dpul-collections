defmodule DpulCollections.IndexingPipelineFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DpulCollections.IndexingPipeline` context.
  """

  @doc """
  Generate a hydration_cache_entry.
  """
  def hydration_cache_entry_fixture(attrs \\ %{}) do
    {:ok, hydration_cache_entry} =
      attrs
      |> Enum.into(%{
        cache_version: 42,
        data: "some data",
        record_id: "some record_id",
        source_cache_order: ~U[2024-07-23 20:05:00Z]
      })
      |> DpulCollections.IndexingPipeline.create_hydration_cache_entry()

    hydration_cache_entry
  end
end

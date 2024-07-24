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

  @doc """
  Generate a processor_marker.
  """
  def processor_marker_fixture(attrs \\ %{}) do
    {:ok, processor_marker} =
      attrs
      |> Enum.into(%{
        cache_location: ~U[2024-07-23 20:40:00Z],
        cache_version: 42,
        type: "some type"
      })
      |> DpulCollections.IndexingPipeline.create_processor_marker()

    processor_marker
  end
end

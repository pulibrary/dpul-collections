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
        data: %{},
        record_id: "some record_id",
        related_ids: [],
        source_cache_order: ~U[2024-07-23 20:05:00Z],
        source_cache_order_record_id: "some record_id"
      })
      |> DpulCollections.IndexingPipeline.write_hydration_cache_entry()

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
        type: "some type",
        cache_record_id: "3cb7627b-defc-401b-9959-42ebc4488f74"
      })
      |> DpulCollections.IndexingPipeline.write_processor_marker()

    processor_marker
  end

  @doc """
  Generate a transformation_cache_entry.
  """
  def transformation_cache_entry_fixture(attrs \\ %{}) do
    {:ok, transformation_cache_entry} =
      attrs
      |> Enum.into(%{
        cache_version: 42,
        data: %{},
        record_id: "some record_id",
        source_cache_order: ~U[2024-07-23 20:05:00Z]
      })
      |> DpulCollections.IndexingPipeline.write_transformation_cache_entry()

    transformation_cache_entry
  end
end

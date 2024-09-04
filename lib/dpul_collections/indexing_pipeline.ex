defmodule DpulCollections.IndexingPipeline do
  @moduledoc """
  The IndexingPipeline context.
  """

  import Ecto.Query, warn: false
  alias DpulCollections.{Repo, FiggyRepo}

  alias DpulCollections.IndexingPipeline.{
    FiggyHydrationCacheEntry,
    FiggyHydrationCacheEntryMarker,
    FiggyResource,
    ResourceMarker
  }

  @doc """
  Returns the list of figgy_hydration_cache_entries.

  ## Examples

      iex> list_figgy_hydration_cache_entries()
      [%FiggyHydrationCacheEntry{}, ...]

  """
  def list_figgy_hydration_cache_entries do
    Repo.all(FiggyHydrationCacheEntry)
  end

  @doc """
  Gets a single figgy_hydration_cache_entry.

  Raises `Ecto.NoResultsError` if the Hydration cache entry does not exist.

  ## Examples

      iex> get_figgy_hydration_cache_entry!(123)
      %FiggyHydrationCacheEntry{}

      iex> get_figgy_hydration_cache_entry!(456)
      ** (Ecto.NoResultsError)

  """
  def get_figgy_hydration_cache_entry!(id), do: Repo.get!(FiggyHydrationCacheEntry, id)

  @doc """
  Deletes a figgy_hydration_cache_entry.

  ## Examples

      iex> delete_figgy_hydration_cache_entry(figgy_hydration_cache_entry)
      {:ok, %FiggyHydrationCacheEntry{}}

      iex> delete_figgy_hydration_cache_entry(figgy_hydration_cache_entry)
      {:error, %Ecto.Changeset{}}

  """
  def delete_figgy_hydration_cache_entry(%FiggyHydrationCacheEntry{} = figgy_hydration_cache_entry) do
    Repo.delete(figgy_hydration_cache_entry)
  end

  @doc """
  Writes or updates hydration cache entries.
  """
  def write_figgy_hydration_cache_entry(attrs \\ %{}) do
    conflict_query =
      FiggyHydrationCacheEntry
      |> update(set: [data: ^attrs.data, source_cache_order: ^attrs.source_cache_order])
      |> where([c], c.source_cache_order <= ^attrs.source_cache_order)

    try do
      %FiggyHydrationCacheEntry{}
      |> FiggyHydrationCacheEntry.changeset(attrs)
      |> Repo.insert(
        on_conflict: conflict_query,
        conflict_target: [:cache_version, :record_id]
      )
    rescue
      Ecto.StaleEntryError -> {:ok, nil}
    end
  end

  @spec get_figgy_hydration_cache_entries_since!(
          marker :: FiggyHydrationCacheEntryMarker.t(),
          count :: integer
        ) :: list(FiggyHydrationCacheEntry)
  def get_figgy_hydration_cache_entries_since!(
        %FiggyHydrationCacheEntryMarker{timestamp: source_cache_order, id: id},
        count
      ) do
    query =
      from r in FiggyHydrationCacheEntry,
        where:
          (r.source_cache_order == ^source_cache_order and r.record_id > ^id) or
            r.source_cache_order > ^source_cache_order,
        limit: ^count,
        order_by: [asc: r.source_cache_order, asc: r.record_id]

    Repo.all(query)
  end

  @spec get_figgy_hydration_cache_entries_since!(
          nil,
          count :: integer
        ) :: list(FiggyHydrationCacheEntry)
  def get_figgy_hydration_cache_entries_since!(nil, count) do
    query =
      from r in FiggyHydrationCacheEntry,
        limit: ^count,
        order_by: [asc: r.source_cache_order, asc: r.record_id]

    Repo.all(query)
  end

  alias DpulCollections.IndexingPipeline.ProcessorMarker

  @doc """
  Returns the list of processor_markers.

  ## Examples

      iex> list_processor_markers()
      [%ProcessorMarker{}, ...]

  """
  def list_processor_markers do
    Repo.all(ProcessorMarker)
  end

  @doc """
  Gets a single processor_marker.

  Raises `Ecto.NoResultsError` if the Processor marker does not exist.

  ## Examples

      iex> get_processor_marker!(123)
      %ProcessorMarker{}

      iex> get_processor_marker!(456)
      ** (Ecto.NoResultsError)

  """
  def get_processor_marker!(id), do: Repo.get!(ProcessorMarker, id)

  @doc """
  Gets the processor marker for a specific cache version
  """
  def get_processor_marker!(type, cache_version) do
    Repo.get_by(ProcessorMarker, type: type, cache_version: cache_version)
  end

  @doc """
  Deletes a processor_marker.

  ## Examples

      iex> delete_processor_marker(processor_marker)
      {:ok, %ProcessorMarker{}}

      iex> delete_processor_marker(processor_marker)
      {:error, %Ecto.Changeset{}}

  """
  def delete_processor_marker(%ProcessorMarker{} = processor_marker) do
    Repo.delete(processor_marker)
  end

  @doc """
  Writes or updates processor markers
  """
  def write_processor_marker(attrs \\ %{}) do
    %ProcessorMarker{}
    |> ProcessorMarker.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [cache_location: attrs.cache_location, cache_record_id: attrs.cache_record_id]
      ],
      conflict_target: [:type, :cache_version]
    )
  end

  @doc """
  Gets a single Resource by id from Figgy Database.

  Raises `Ecto.NoResultsError` if the Resource does not exist.

  ## Examples

      iex> get_figgy_resource!(123)
      %FiggyHydrationCacheEntry{}

      iex> get_figgy_resource!(456)
      ** (Ecto.NoResultsError)

  """
  def get_figgy_resource!(id), do: FiggyRepo.get!(FiggyResource, id)

  @doc """
  ## Description
  Query to return a limited number of figgy resources using the value of a marker tuple.

  1. Orders figgy records by updated_at and then id in ascending order
  2. Selects records where
      - record.updated_at equals to marker.updated_at AND
      - record.id is greater than marker.id
      - OR
      - record.updated_at is greater than marker.updated_at
  3. Return the number of records indicated by the count parameter

  ## Examples

    Records in Figgy:
      { id: "a", updated_at: 1 }
      { id: "b", updated_at: 2 }
      { id: "d", updated_at: 3 } # Duplicate time stamp
      { id: "c", updated_at: 3 } # Duplicate time stamp
      { id: "e", updated_at: 3 } # Duplicate time stamp
      { id: "a", updated_at: 4 } # Repeated id (edited and saved)

    Function calls:

      We get the records back ordered by timestamp, then id:

      get_figgy_resources_since!({1, "a"}, 2) ->
      { id: "b", updated_at: 2 }
      { id: "c", updated_at: 3 }


      We get the records for the same time stamp for ids after the one given:

      get_figgy_resources_since!({3, "c"}, 3) ->
      { id: "d", updated_at: 3 }
      { id: "e", updated_at: 3 }
      { id: "a", updated_at: 4 }


      We get a record again if it's been updated since it was last fetched:

      get_figgy_resources_since!({1, "a"}, 5) ->
      { id: "b", updated_at: 2 }
      { id: "c", updated_at: 3 }
      { id: "d", updated_at: 3 }
      { id: "e", updated_at: 3 }
      { id: "a", updated_at: 4 }
  """

  @spec get_figgy_resources_since!(
          marker :: ResourceMarker.t(),
          count :: integer
        ) :: list(FiggyResource)
  def get_figgy_resources_since!(%ResourceMarker{timestamp: updated_at, id: id}, count) do
    query =
      from r in FiggyResource,
        where: (r.updated_at == ^updated_at and r.id > ^id) or r.updated_at > ^updated_at,
        limit: ^count,
        order_by: [asc: r.updated_at, asc: r.id]

    FiggyRepo.all(query)
  end

  @spec get_figgy_resources_since!(
          nil,
          count :: integer
        ) :: list(FiggyResource)
  def get_figgy_resources_since!(nil, count) do
    query =
      from r in FiggyResource,
        limit: ^count,
        order_by: [asc: r.updated_at, asc: r.id]

    FiggyRepo.all(query)
  end

  alias DpulCollections.IndexingPipeline.TransformationCacheEntry

  @doc """
  Returns the list of transformation_cache_entries.

  ## Examples

      iex> list_transformation_cache_entries()
      [%TransformationCacheEntry{}, ...]

  """
  def list_transformation_cache_entries do
    Repo.all(TransformationCacheEntry)
  end

  @doc """
  Gets a single transformation_cache_entry.

  Raises `Ecto.NoResultsError` if the Hydration cache entry does not exist.

  ## Examples

      iex> get_transformation_cache_entry!(123)
      %TransformationCacheEntry{}

      iex> get_transformation_cache_entry!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transformation_cache_entry!(id), do: Repo.get!(TransformationCacheEntry, id)

  @doc """
  Deletes a transformation_cache_entry.

  ## Examples

      iex> delete_transformation_cache_entry(transformation_cache_entry)
      {:ok, %TransformationCacheEntry{}}

      iex> delete_transformation_cache_entry(transformation_cache_entry)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transformation_cache_entry(%TransformationCacheEntry{} = transformation_cache_entry) do
    Repo.delete(transformation_cache_entry)
  end

  @doc """
  Writes or updates transformation cache entries.
  """
  def write_transformation_cache_entry(attrs \\ %{}) do
    conflict_query =
      TransformationCacheEntry
      |> update(set: [data: ^attrs.data, source_cache_order: ^attrs.source_cache_order])
      |> where([c], c.source_cache_order <= ^attrs.source_cache_order)

    try do
      %TransformationCacheEntry{}
      |> TransformationCacheEntry.changeset(attrs)
      |> Repo.insert(
        on_conflict: conflict_query,
        conflict_target: [:cache_version, :record_id]
      )
    rescue
      Ecto.StaleEntryError -> {:ok, nil}
    end
  end
end

defmodule DpulCollections.IndexingPipeline do
  @moduledoc """
  The IndexingPipeline context.
  """

  import Ecto.Query, warn: false
  alias DpulCollections.{Repo, FiggyRepo}

  alias DpulCollections.IndexingPipeline.{HydrationCacheEntry, FiggyResource, ResourceMarker}

  @doc """
  Returns the list of hydration_cache_entries.

  ## Examples

      iex> list_hydration_cache_entries()
      [%HydrationCacheEntry{}, ...]

  """
  def list_hydration_cache_entries do
    Repo.all(HydrationCacheEntry)
  end

  @doc """
  Gets a single hydration_cache_entry.

  Raises `Ecto.NoResultsError` if the Hydration cache entry does not exist.

  ## Examples

      iex> get_hydration_cache_entry!(123)
      %HydrationCacheEntry{}

      iex> get_hydration_cache_entry!(456)
      ** (Ecto.NoResultsError)

  """
  def get_hydration_cache_entry!(id), do: Repo.get!(HydrationCacheEntry, id)

  @doc """
  Updates a hydration_cache_entry.

  ## Examples

      iex> update_hydration_cache_entry(hydration_cache_entry, %{field: new_value})
      {:ok, %HydrationCacheEntry{}}

      iex> update_hydration_cache_entry(hydration_cache_entry, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_hydration_cache_entry(%HydrationCacheEntry{} = hydration_cache_entry, attrs) do
    hydration_cache_entry
    |> HydrationCacheEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a hydration_cache_entry.

  ## Examples

      iex> delete_hydration_cache_entry(hydration_cache_entry)
      {:ok, %HydrationCacheEntry{}}

      iex> delete_hydration_cache_entry(hydration_cache_entry)
      {:error, %Ecto.Changeset{}}

  """
  def delete_hydration_cache_entry(%HydrationCacheEntry{} = hydration_cache_entry) do
    Repo.delete(hydration_cache_entry)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking hydration_cache_entry changes.

  ## Examples

      iex> change_hydration_cache_entry(hydration_cache_entry)
      %Ecto.Changeset{data: %HydrationCacheEntry{}}

  """
  def change_hydration_cache_entry(%HydrationCacheEntry{} = hydration_cache_entry, attrs \\ %{}) do
    HydrationCacheEntry.changeset(hydration_cache_entry, attrs)
  end

  @doc """
  Writes or updates hydration cache entries.
  """
  def write_hydration_cache_entry(attrs \\ %{}) do
    conflict_query =
      HydrationCacheEntry
      |> update(set: [data: ^attrs.data, source_cache_order: ^attrs.source_cache_order])
      |> where([c], c.source_cache_order <= ^attrs.source_cache_order)

    try do
      %HydrationCacheEntry{}
      |> HydrationCacheEntry.changeset(attrs)
      |> Repo.insert(
        on_conflict: conflict_query,
        conflict_target: [:cache_version, :record_id]
      )
    rescue
      Ecto.StaleEntryError -> {:ok, nil}
    end
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
      %HydrationCacheEntry{}

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
end

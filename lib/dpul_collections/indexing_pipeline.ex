defmodule DpulCollections.IndexingPipeline do
  @moduledoc """
  The IndexingPipeline context.
  """

  import Ecto.Query, warn: false
  alias DpulCollections.{Repo, FiggyRepo}

  alias DpulCollections.IndexingPipeline.HydrationCacheEntry

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
  Creates a hydration_cache_entry.

  ## Examples

      iex> create_hydration_cache_entry(%{field: value})
      {:ok, %HydrationCacheEntry{}}

      iex> create_hydration_cache_entry(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_hydration_cache_entry(attrs \\ %{}) do
    %HydrationCacheEntry{}
    |> HydrationCacheEntry.changeset(attrs)
    |> Repo.insert()
  end

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
  Creates a processor_marker.

  ## Examples

      iex> create_processor_marker(%{field: value})
      {:ok, %ProcessorMarker{}}

      iex> create_processor_marker(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_processor_marker(attrs \\ %{}) do
    %ProcessorMarker{}
    |> ProcessorMarker.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a processor_marker.

  ## Examples

      iex> update_processor_marker(processor_marker, %{field: new_value})
      {:ok, %ProcessorMarker{}}

      iex> update_processor_marker(processor_marker, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_processor_marker(%ProcessorMarker{} = processor_marker, attrs) do
    processor_marker
    |> ProcessorMarker.changeset(attrs)
    |> Repo.update()
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
  Returns an `%Ecto.Changeset{}` for tracking processor_marker changes.

  ## Examples

      iex> change_processor_marker(processor_marker)
      %Ecto.Changeset{data: %ProcessorMarker{}}

  """
  def change_processor_marker(%ProcessorMarker{} = processor_marker, attrs \\ %{}) do
    ProcessorMarker.changeset(processor_marker, attrs)
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
end

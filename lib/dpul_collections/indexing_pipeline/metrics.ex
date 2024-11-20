defmodule DpulCollections.IndexingPipeline.Metrics do
  import Ecto.Query, warn: false
  alias DpulCollections.Repo
  alias DpulCollections.IndexingPipeline.IndexMetric

  @doc """
  Creates an IndexMetric
  """
  def create_index_metric(attrs \\ %{}) do
    {:ok, index_metric} =
      %IndexMetric{}
      |> IndexMetric.changeset(attrs)
      |> Repo.insert()

    index_metric
  end

  @doc """
  Get index metrics by type
  """
  def index_metrics(type, measurement_type) do
    query =
      from r in IndexMetric,
        where: r.type == ^type and r.measurement_type == ^measurement_type

    Repo.all(query)
  end
end

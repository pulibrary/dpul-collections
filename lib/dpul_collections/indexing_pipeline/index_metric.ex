defmodule DpulCollections.IndexingPipeline.IndexMetric do
  use Ecto.Schema
  import Ecto.Changeset

  schema "index_metrics" do
    field :type, :string
    field :measurement_type, :string
    # Duration in seconds
    field :duration, :integer
    field :records_acked, :integer, default: 0
    field :cache_version, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(index_metric, attrs) do
    index_metric
    |> cast(attrs, [:type, :measurement_type, :duration, :records_acked, :cache_version])
    |> validate_required([:type, :measurement_type, :duration, :records_acked, :cache_version])
  end
end

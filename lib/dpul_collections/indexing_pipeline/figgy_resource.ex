defmodule DpulCollections.IndexingPipeline.FiggyResource do
  @moduledoc """
  Documentation for ExManifestApi.Resource
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "orm_resources" do
    field :internal_resource, :string
    field :lock_version, :integer
    field :metadata, :map
    field :created_at, :naive_datetime
    field :updated_at, :naive_datetime
  end
end

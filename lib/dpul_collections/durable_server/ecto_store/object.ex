defmodule DpulCollections.DurableServer.EctoStore.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:key, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  schema "durable_server_objects" do
    field :body, :map
    field :version, :integer, default: 1

    timestamps()
  end

  def changeset(object, attrs) do
    object
    |> cast(attrs, [:key, :body])
    |> validate_required([:key, :body])
  end

  def update_changeset(object, attrs) do
    object
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> optimistic_lock(:version)
  end
end

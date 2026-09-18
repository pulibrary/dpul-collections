defmodule DpulCollections.DistributedOcr.ClientStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ocr_clients" do
    field :client_id, :string
    field :status, :string, default: "idle"
    field :image_url, :string
    field :manifest_label, :string
    field :page_label, :string
    field :last_seen_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, [:client_id, :status, :image_url, :manifest_label, :page_label, :last_seen_at])
    |> validate_required([:client_id])
  end
end

defmodule DpulCollections.DistributedOcr.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ocr_jobs" do
    field :image_url, :string
    field :manifest_url, :string
    field :manifest_label, :string
    field :page_label, :string
    field :mode, :string, default: "ocr"
    field :status, :string, default: "queued"
    field :claimed_by, :string
    field :claimed_at, :utc_datetime_usec
    field :lease_expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :image_url,
      :manifest_url,
      :manifest_label,
      :page_label,
      :mode,
      :status,
      :claimed_by,
      :claimed_at,
      :lease_expires_at
    ])
    |> validate_required([:image_url])
  end
end

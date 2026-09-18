defmodule DpulCollections.DistributedOcr.Result do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ocr_results" do
    field :image_url, :string
    field :text, :string
    field :client_id, :string
    field :model, :string
    field :model_version, :string
    field :duration_ms, :integer
    field :manifest_url, :string
    field :manifest_label, :string
    field :page_label, :string
    field :ocr_job_id, :id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :image_url,
      :text,
      :client_id,
      :model,
      :model_version,
      :duration_ms,
      :manifest_url,
      :manifest_label,
      :page_label,
      :ocr_job_id
    ])
    |> validate_required([:image_url, :client_id])
  end
end

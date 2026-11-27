defmodule DpulCollections.Georef.Collab.Atlas do
  @moduledoc "An atlas queued for volunteers (see `DpulCollections.Georef.Collab.Queue`)."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "georef_atlases" do
    field :manifest, :string
    field :label, :string
    field :bbox, {:array, :float}
    field :exclude_keys, {:array, :string}, default: []
    field :canvases, {:array, :map}, default: []
    field :renames, :map, default: %{}
    has_many :jobs, DpulCollections.Georef.Collab.Job

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(a, attrs) do
    a
    |> cast(attrs, [:manifest, :label, :bbox, :exclude_keys, :canvases])
    |> validate_required([:manifest, :bbox])
  end

  @doc """
  The shape `Collab` uses for atlases (a `mix georef` report's top level),
  with the raw canvases under "sheets"; `Collab.atlas/1` adds the part list
  ("canvases") from the finished jobs.
  """
  def base(%__MODULE__{} = a) do
    %{
      "id" => a.id,
      "source" => "queue",
      "label" => a.label,
      "manifest" => a.manifest,
      "bbox" => a.bbox,
      "exclude_keys" => a.exclude_keys,
      "renames" => %{"table" => a.renames || %{}},
      "sheets" => a.canvases,
      "canvases" => []
    }
  end
end

defmodule DpulCollections.Georef.Collab.Contribution do
  @moduledoc """
  One volunteer's result for one map part: where their browser (and they)
  placed it, or that it can't be placed. The IIIF Georeference Annotation is
  stored with it so contributors can download exactly what they made.
  """
  use DpulCollections.Schema
  import Ecto.Changeset

  schema "georef_contributions" do
    field :atlas_id, :string
    field :atlas_label, :string
    field :canvas_id, :string
    field :canvas_label, :string
    field :part, :integer, default: 1
    field :verdict, :string
    field :method, :string
    field :transform, :map
    field :projection, :map
    field :scores, :map
    field :compute, :map
    field :annotation, :map
    belongs_to :user, DpulCollections.Accounts.User, type: :id

    timestamps(type: :utc_datetime_usec)
  end

  @fields ~w(atlas_id atlas_label canvas_id canvas_label part verdict method transform projection scores compute annotation)a

  def changeset(c, attrs, user) do
    c
    |> cast(attrs, @fields)
    |> validate_required([:atlas_id, :canvas_id, :part, :verdict])
    |> validate_inclusion(:verdict, ~w(placed cannot))
    |> validate_inclusion(:method, ~w(auto adjusted))
    |> put_change(:user_id, user.id)
  end
end

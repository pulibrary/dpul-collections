defmodule DpulCollections.UserSets.SetItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_set_items" do
    field :solr_id, :string
    belongs_to :set, DpulCollections.UserSets.Set

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(set_item, attrs) do
    set_item
    |> cast(attrs, [:solr_id, :set_id])
    |> validate_required([:solr_id])
  end
end

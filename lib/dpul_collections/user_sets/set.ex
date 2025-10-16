defmodule DpulCollections.UserSets.Set do
  use DpulCollections.Schema
  import Ecto.Changeset

  schema "user_sets" do
    field :title, :string
    field :description, :string
    # Virtual fields to support the display for Add to Set.
    field :set_item_count, :integer, virtual: true
    field :has_solr_id, :boolean, virtual: true, default: false
    belongs_to :user, DpulCollections.Accounts.User, type: :id
    has_many :set_items, DpulCollections.UserSets.SetItem

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(set, attrs, user_scope) do
    set
    |> cast(attrs, [:title, :description])
    |> cast_assoc(:set_items)
    |> validate_required([:title])
    |> put_change(:user_id, user_scope.user.id)
  end
end

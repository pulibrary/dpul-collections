defmodule DpulCollections.UserSets.Set do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_sets" do
    field :title, :string
    field :description, :string
    belongs_to :user, DpulCollections.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(set, attrs, user_scope) do
    set
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
    |> put_change(:user_id, user_scope.user.id)
  end
end

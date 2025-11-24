defmodule DpulCollections.Correction do
  import Ecto.Changeset

  defstruct [:name, :email, :message, :item_id]

  def changeset(correction, attrs) do
    types = %{name: :string, email: :string, message: :string, item_id: :string}

    {correction, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required([:message, :item_id])
    |> validate_format(:email, ~r/@/)
  end
end

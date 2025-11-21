defmodule DpulCollectionsWeb.CorrectionTest do
  use DpulCollections.DataCase
  alias DpulCollections.Correction

  describe "changeset" do
    test "can create a valid change set from form params" do
      params = %{
        "name" => "me",
        "email" => "me@example.com",
        "message" => "a correction",
        "item_id" => "2"
      }

      correction = %Correction{} |> Correction.changeset(params)
      assert correction.valid?
    end

    test "requires a message" do
      params = %{
        "item_id" => "2"
      }

      correction = %Correction{} |> Correction.changeset(params)
      refute correction.valid?
    end

    test "requires an item_id" do
      params = %{
        "message" => "a correction"
      }

      correction = %Correction{} |> Correction.changeset(params)
      refute correction.valid?
    end

    test "validates email format" do
      params = %{
        "email" => "example.com",
        "item_id" => "2",
        "message" => "a correction"
      }

      correction = %Correction{} |> Correction.changeset(params)
      refute correction.valid?
    end
  end
end

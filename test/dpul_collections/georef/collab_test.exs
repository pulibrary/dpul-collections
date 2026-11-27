defmodule DpulCollections.Georef.CollabTest do
  use DpulCollections.DataCase
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Georef.{Collab, Geometry}

  @atlas %{
    "id" => "00000000-0000-0000-0000-000000000001",
    "label" => "Insurance maps of Testtown",
    "manifest" => "https://figgy.example/manifest",
    "bbox" => [-74.7, 40.3, -74.6, 40.4],
    "canvases" => [
      %{
        "id" => "https://figgy.example/canvas/1",
        "label" => "Sheet 1",
        "part" => 1,
        "status" => "ok",
        "service" => "https://iiif-cloud.princeton.edu/iiif/2/abc",
        "width" => 1000,
        "height" => 800,
        "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
        "labels" => [],
        "transform" => %{"a" => 0.04, "b" => 0.0, "tx" => 10.0, "ty" => 20.0}
      },
      %{
        "id" => "https://figgy.example/canvas/2",
        "label" => "Sheet 2",
        "part" => 1,
        "status" => "failed",
        "service" => "https://iiif-cloud.princeton.edu/iiif/2/def",
        "width" => 1000,
        "height" => 800,
        "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
        "labels" => [],
        "transform" => nil
      }
    ]
  }

  test "a volunteer's placement is saved with its annotation, credited, and wins in the atlas page" do
    user = user_fixture()
    t = %{"a" => 0.0, "b" => 0.04, "tx" => 5.0, "ty" => 6.0}

    {:ok, c} =
      Collab.save(user, @atlas, 1, %{
        "verdict" => "placed",
        "method" => "auto",
        "transform" => t,
        "scores" => %{"label_hits" => 5}
      })

    assert c.user_id == user.id
    assert [%{id: id}] = Collab.list_for_user(user)
    assert id == c.id

    a = c.annotation
    assert a["creator"]["id"] == "urn:dpul:user:#{user.id}"

    assert a["target"]["source"]["partOf"] |> hd() |> Map.get("id") ==
             "https://figgy.example/canvas/2"

    # control points are the outline corners carried through the transform
    [f | _] = a["body"]["features"]
    p = Collab.projection(@atlas)
    {x, y} = Geometry.transform(%{a: 0.0, b: 0.04, tx: 5.0, ty: 6.0}, {0, 0})
    [lon, lat] = Geometry.to_lonlat(p, {x, y})
    assert f["properties"]["resourceCoords"] == [0, 0]
    assert_in_delta hd(f["geometry"]["coordinates"]), lon, 1.0e-6
    assert_in_delta List.last(f["geometry"]["coordinates"]), lat, 1.0e-6

    page = Collab.atlas_page(@atlas)
    # Sheet 1 from the server prototype, Sheet 2 from the volunteer
    assert length(page["items"]) == 2
    assert Enum.at(page["items"], 1)["creator"]
  end

  test "\"can't place\" removes the server fit from the atlas page" do
    user = user_fixture()
    {:ok, _} = Collab.save(user, @atlas, 0, %{"verdict" => "cannot"})
    assert Collab.atlas_page(@atlas)["items"] == []
  end

  test "only Princeton's image server is proxied" do
    assert Collab.allowed_service?("https://iiif-cloud.princeton.edu/iiif/2/abc")
    refute Collab.allowed_service?("http://169.254.169.254/latest")
    refute Collab.allowed_service?("https://evil.example/iiif")
  end
end

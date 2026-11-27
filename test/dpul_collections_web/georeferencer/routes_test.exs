defmodule DpulCollectionsWeb.Georeferencer.RoutesTest do
  use DpulCollectionsWeb.ConnCase, async: false
  alias DpulCollectionsWeb.Georeferencer.Routes

  setup do
    old = Application.get_env(:dpul_collections, :georeferencer)
    on_exit(fn -> Application.put_env(:dpul_collections, :georeferencer, old) end)
  end

  test "switched on, the pages are there", %{conn: conn} do
    assert Routes.enabled?()
    assert conn |> get(~p"/georeferencer") |> html_response(200) =~ "Queue"
  end

  test "switched off, every georeferencer request is a 404", %{conn: conn} do
    Application.put_env(:dpul_collections, :georeferencer, enabled: false)
    refute Routes.enabled?()

    for path <- ["/georeferencer", "/georeferencer/review", "/georeferencer/atlas/x/osm.json"] do
      assert conn |> get(path) |> response(404) == "Not Found"
    end

    # a LiveView reached over its websocket, past the plugs
    assert_raise DpulCollectionsWeb.ItemLive.NotFoundError, fn ->
      Routes.on_mount(:enabled, %{}, %{}, %Phoenix.LiveView.Socket{})
    end
  end

  test "off unless configured" do
    Application.delete_env(:dpul_collections, :georeferencer)
    refute Routes.enabled?()
  end
end

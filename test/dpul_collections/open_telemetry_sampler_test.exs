defmodule DpulCollections.OpenTelemetrySamplerTest do
  use DpulCollections.DataCase
  use DpulCollections.TracingHelpers

  test "ignores asset paths and socket stuff" do
    for path <- [
          "/assets/js/app.js",
          "/fonts/poppins.woff2",
          "/robots.txt",
          "/phoenix/live_reload/socket/websocket",
          "/live/websocket",
          "/live/longpoll",
          "/health"
        ] do
      Tracer.with_span "GET", %{attributes: %{"url.path": path}} do
        Tracer.with_span("child", do: :ok)
      end
    end

    refute_receive {:span, span(name: "GET")}, 500
    refute_receive {:span, span(name: "child")}
  end

  test "keeps other paths" do
    Tracer.with_span "GET", %{attributes: %{"url.path": "/awesome"}} do
      Tracer.with_span("child", do: :ok)
    end
    # This one's probably not real - just testing the fall-through case, only
    # way I could get it to happen was to not a leading slash.
    Tracer.with_span "POST", %{attributes: %{"url.path": "sup"}}, do: :ok

    assert_receive {:span, span(name: "GET")}, 1000
    assert_receive {:span, span(name: "POST")}, 1000
    assert_receive {:span, span(name: "child")}, 1000
  end

  test "drops changedCanvas but not other events" do
    Tracer.with_span "DpulCollectionsWeb.ItemLive.handle_event#changedCanvas" do
      Tracer.with_span("DpulCollectionsWeb.ItemLive.handle_params", do: :ok)
    end

    Tracer.with_span("DpulCollectionsWeb.SearchLive.handle_event#select_filter_tab", do: :ok)

    assert_receive {:span,
                    span(name: "DpulCollectionsWeb.SearchLive.handle_event#select_filter_tab")},
                   1000

    refute_received {:span, span(name: "DpulCollectionsWeb.ItemLive.handle_event#changedCanvas")}
    refute_received {:span, span(name: "DpulCollectionsWeb.ItemLive.handle_params")}
  end

  test "drops database queries without a parent" do
    Repo.query!("SELECT 1")

    refute_receive {:span, span(name: "dpul_collections.repo.query")}, 500
  end

  test "keeps database queries with a parent span" do
    Tracer.with_span "parent" do
      Repo.query!("SELECT 1")
    end

    assert_receive {:span, span(name: "parent", span_id: parent_id)}, 1000
    assert_receive {:span, span(name: "dpul_collections.repo.query", parent_span_id: ^parent_id)}
  end
end

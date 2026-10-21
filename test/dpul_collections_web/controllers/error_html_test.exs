defmodule DpulCollectionsWeb.ErrorHTMLTest do
  use DpulCollectionsWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(DpulCollectionsWeb.ErrorHTML, "404", "html", []) =~ "Page Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(DpulCollectionsWeb.ErrorHTML, "500", "html", []) =~
             "Internal Server Error"
  end

  # this test ensures full coverage by testing the fallthrough of error pages that we haven't customized
  test "renders 503.html" do
    assert render_to_string(DpulCollectionsWeb.ErrorHTML, "503", "html", []) =~
             "Service Unavailable"
  end
end

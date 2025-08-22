defmodule DpulCollectionsWeb.CoreComponents.ButtonTest do
    use DpulCollectionsWeb.ConnCase, async: true

    import Phoenix.LiveViewTest
    import DpulCollectionsWeb.CoreComponents

    def slot(content) do
        [
            %{
            inner_block: fn _assigns, _slot_assigns -> content end
            }
        ]
    end

   test "primary button renders as <button> when no href/patch" do
    html =
        render_component(&primary_button/1,
            inner_block: slot("Click me")
        )

        assert html =~ "<button"
        assert html =~ "btn-primary"
        assert html =~ "Click me"
    end

    test "primary button renders as <a> when href is set" do
        html =
        render_component(&primary_button/1,
            href: "/home",
            inner_block: slot("Home")
        )

        assert html =~ ~s(href="/home")
        assert html =~ "btn-primary"
    end

    test "primary button renders disabled <span> when href is set and disabled" do
        html =
        render_component(&primary_button/1,
            href: "/home",
            disabled: true,
            inner_block: slot("Home")
        )

        assert html =~ ~s(<span)
        assert html =~ "disabled"
        refute html =~ ~s(href=)
    end

end
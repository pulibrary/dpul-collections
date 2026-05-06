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

  test "secondary button renders as <button> when no href/patch" do
    html =
      render_component(&secondary_button/1,
        inner_block: slot("Click me")
      )

    assert html =~ "<button"
    assert html =~ "btn-secondary"
    assert html =~ "Click me"
  end

  test "secondary button renders as <a> when href is set" do
    html =
      render_component(&secondary_button/1,
        href: "/home",
        inner_block: slot("Home")
      )

    assert html =~ ~s(href="/home")
    assert html =~ "btn-secondary"
  end

  test "secondary button renders disabled <span> when href is set and disabled" do
    html =
      render_component(&secondary_button/1,
        href: "/home",
        disabled: true,
        inner_block: slot("Home")
      )

    assert html =~ ~s(<span)
    assert html =~ "disabled"
    refute html =~ ~s(href=)
  end

  test "danger button renders as <button> when no href/patch" do
    html =
      render_component(&danger_button/1,
        inner_block: slot("Click me")
      )

    assert html =~ "<button"
    assert html =~ "btn-danger"
    assert html =~ "Click me"
  end

  test "danger button renders as <a> when href is set" do
    html =
      render_component(&danger_button/1,
        href: "/home",
        inner_block: slot("Home")
      )

    assert html =~ ~s(href="/home")
    assert html =~ "btn-danger"
  end

  test "danger button renders disabled <span> when href is set and disabled" do
    html =
      render_component(&danger_button/1,
        href: "/home",
        disabled: true,
        inner_block: slot("Home")
      )

    assert html =~ ~s(<span)
    assert html =~ "disabled"
    refute html =~ ~s(href=)
  end

  test "transparent button renders as <button> when no href/patch" do
    html =
      render_component(&transparent_button/1,
        inner_block: slot("Click me")
      )

    assert html =~ "<button"
    assert html =~ "btn-transparent"
    assert html =~ "Click me"
  end

  test "transparent button renders as <a> when navigate is set" do
    html =
      render_component(&transparent_button/1,
        navigate: "/home",
        inner_block: slot("Home")
      )

    assert html =~ ~s(href="/home")
    assert html =~ "btn-transparent"
  end

  test "transparent button renders disabled <span> when href is set and disabled" do
    html =
      render_component(&transparent_button/1,
        navigate: "/home",
        disabled: true,
        inner_block: slot("Home")
      )

    assert html =~ ~s(<span)
    assert html =~ "disabled"
    refute html =~ ~s(href=)
  end

  test "left arrow button renders a <div> within an <a> when href is set" do
    html =
      render_component(&arrow_button_left/1,
        patch: "/home",
        inner_block: slot("Home")
      )

    assert html =~ ~s(<div)
    assert html =~ ~s(href="/home")
    assert html =~ "left-arrow-box"
  end

  test "left arrow button renders a single <span> when href is set and disabled" do
    html =
      render_component(&arrow_button_left/1,
        patch: "/home",
        disabled: true,
        inner_block: slot("Home")
      )

    assert html =~ ~s(<span)
    assert html =~ "disabled"
    refute html =~ ~s(href=)
    assert html =~ "left-arrow-box"
  end

  test "right arrow button renders a <div> within an <a> when href is set" do
    html =
      render_component(&arrow_button_right/1,
        patch: "/home",
        inner_block: slot("Home")
      )

    assert html =~ ~s(<div)
    assert html =~ ~s(href="/home")
    assert html =~ "right-arrow-box"
  end

  test "right arrow button renders a single <span> when href is set and disabled" do
    html =
      render_component(&arrow_button_right/1,
        patch: "/home",
        disabled: true,
        inner_block: slot("Home")
      )

    assert html =~ ~s(<span)
    assert html =~ "disabled"
    refute html =~ ~s(href=)
    assert html =~ "right-arrow-box"
  end

  test "icon button renders as <a> when href is set" do
    html =
      render_component(&icon_button/1,
        href: "/next",
        icon: "hero-arrow-right-circle-solid",
        button_text: "Next"
      )

    assert html =~ ~s(href="/next")
    assert html =~ "btn-icon"
  end

  test "icon button renders disabled <span> when href is set and disabled" do
    html =
      render_component(&icon_button/1,
        disabled: true,
        href: "/next",
        icon: "hero-arrow-right-circle-solid",
        button_text: "Next"
      )

    assert html =~ ~s(<span)
    assert html =~ "disabled"
    refute html =~ ~s(href=)
  end

  describe "translate_error" do
    test "can accept pluralization" do
      text = translate_error({"username should be at least %{count} character(s)", [count: 2]})
      assert text == "username should be at least 2 character(s)"
    end
  end

  describe "translate_errors" do
    test "gives back a list of error messages" do
      list = translate_errors([email: {"not found", []}, token: {"expired", []}], :email)
      assert list == ["not found"]
    end
  end

  describe "format_number" do
    setup do
      # reset locale to original value on exit
      original = Cldr.get_locale(DpulCollectionsWeb.Cldr)
      on_exit(fn -> Cldr.put_locale(DpulCollectionsWeb.Cldr, original) end)
      :ok
    end

    test "uses commas as delimiters if language is English" do
      Cldr.put_locale(DpulCollectionsWeb.Cldr, "en")
      assert format_number(1234) == "1,234"
      assert format_number(1_234_567) == "1,234,567"
    end

    test "uses periods as delimiters if language is Spanish" do
      Cldr.put_locale(DpulCollectionsWeb.Cldr, "es")
      assert format_number(1234) == "1234"
      assert format_number(10000) == "10.000"
      assert format_number(1_234_567) == "1.234.567"
    end

    test "uses periods as delimiters if language is Portuguese" do
      Cldr.put_locale(DpulCollectionsWeb.Cldr, "pt")
      assert format_number(1234) == "1.234"
      assert format_number(1_234_567) == "1.234.567"
    end

    test "does not error with nil value" do
      assert format_number(nil) == nil
    end
  end
end

defmodule DpulCollectionsWeb.LiveHooks.SetLocaleHookTest do
  use ExUnit.Case, async: true

  alias DpulCollectionsWeb.LiveHooks.SetLocaleHook

  @default_locale "en"

  setup do
    # Reset locale before each test to avoid interference
    Gettext.put_locale(DpulCollectionsWeb.Gettext, @default_locale)
    :ok
  end

  test "assigns locale from session" do
    # Arrange
    socket = %Phoenix.LiveView.Socket{}
    session = %{"locale" => "es"}
    params = %{}

    # Act
    {:cont, updated_socket} = SetLocaleHook.on_mount(:default, params, session, socket)

    # Assert
    assert updated_socket.assigns.locale == "es"
    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == "es"
  end

  test "assigns default locale when locale is not in session" do
    # Arrange
    socket = %Phoenix.LiveView.Socket{}
    # No "locale" key
    session = %{}
    params = %{}

    # Act
    {:cont, updated_socket} = SetLocaleHook.on_mount(:default, params, session, socket)

    # Assert
    assert updated_socket.assigns.locale == @default_locale
    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == @default_locale
  end

  test "handles unexpected session structure gracefully" do
    # Arrange
    socket = %Phoenix.LiveView.Socket{}
    # Simulate a nil session
    session = nil
    params = %{}

    # Act
    {:cont, updated_socket} = SetLocaleHook.on_mount(:default, params, session || %{}, socket)

    # Assert
    assert updated_socket.assigns.locale == @default_locale
    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == @default_locale
  end
end

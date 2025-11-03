# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.HeaderComponent do
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  attr :display_title, :boolean, default: true

  attr :current_scope, :map,
    default: nil,
    doc:
      "the current [scope](https://hexdocs.pm/phoenix/scopes.html) -- without this the user's account won't display"

  def header(assigns) do
    ~H"""
    <header class="flex flex-row gap-10 items-center bg-brand header-y-padding header-x-padding">
      
    <!-- logo -->
      <.link href="https://library.princeton.edu">
        <div class="logo flex-none w-9 sm:hidden">
          <img src={~p"/images/local-svgs.svg"} alt={gettext("Princeton University Library Logo")} />
        </div>
        <div class="logo flex-none sm:w-32 md:w-50 hidden sm:flex">
          <!-- the width of the div must match the one on the other side, but keep the image a bit smaller -->
          <img
            class="max-w-40"
            src={~p"/images/pul-logo.svg"}
            alt={gettext("Princeton University Library Logo")}
          />
        </div>
      </.link>
      
    <!-- title -->
      <div class="app_name flex-1 w-auto text-center px-2">
        <.link
          :if={@display_title}
          navigate={~p"/"}
          class="text-lg sm:text-xl md:text-2xl lg:text-3xl sm:inline-block uppercase tracking-widest font-bold text-center"
        >
          {gettext("Digital Collections")}
        </.link>
      </div>

      <nav
        id="nav-menu"
        class="menu relative flex-none justify-end w-9 sm:w-32 md:w-50 flex flex-row"
        aria-label={gettext("Main Navigation")}
        phx-click-away={JS.exec("dcjs-hide-menu", to: "#main-menu-dropdown")}
      >
        <button
          id="menu-toggle"
          class="group md:hidden text-white hover:link-hover font-medium"
          aria-label={gettext("Main menu")}
          aria-expanded="false"
          aria-haspopup="true"
          phx-click={JS.exec("dcjs-toggle-menu", to: "#main-menu-dropdown")}
        >
          <span class="hover:link-hover font-normal sm:font-medium text-sm sm:text-md cursor-pointer">
            <!-- make this switch to an X when expanded -->
            <.icon class="group-[.expanded]:hidden" name="hero-bars-3" />
            <.icon class="not-group-[.expanded]:hidden" name="hero-x-mark" />
          </span>
        </button>
        
    <!-- note: toggle() does not work the same as toggle_class("hidden") when
             moving between viewport sizes -->
        <ul
          id="main-menu-dropdown"
          class={[
            "dropdown",
            "hidden absolute left-auto right-0 top-8 z-10",
            "list-none bg-white min-w-3xs py-2 px-0 mt-2 shadow-md rounded-md",
            "md:bg-brand",
            "md:static md:flex md:flex-row md:gap-4"
          ]}
          dcjs-toggle-menu={
            JS.toggle_attribute({"aria-expanded", "false", "true"}, to: "#menu-toggle")
            |> JS.toggle_class("expanded", to: "#menu-toggle")
            |> JS.toggle_class("hidden")
          }
          dcjs-hide-menu={
            JS.set_attribute({"aria-expanded", "false"})
            |> JS.remove_class("expanded", to: "#menu-toggle")
            |> JS.add_class("hidden")
          }
        >
          <li id="language-nav">
            <button
              class="submenu"
              name={gettext("Language")}
              aria-label={gettext("Language")}
              aria-expanded="false"
              aria-haspopup="true"
              phx-click={
                JS.toggle_attribute({"aria-expanded", "false", "true"})
                |> JS.toggle_class("expanded")
                |> JS.exec("dcjs-toggle-menu", to: "#language-menu")
              }
              phx-click-away={
                JS.set_attribute({"aria-expanded", "false"})
                |> JS.remove_class("expanded")
                |> JS.exec("dcjs-hide-menu", to: "#language-menu")
              }
            >
              <span class="hover:link-hover font-normal sm:font-medium text-sm sm:text-md cursor-pointer">
                {gettext("Language")}&nbsp;<span class="font-normal">&gt;</span>
              </span>
            </button>
            <ul
              id="language-menu"
              class="dropdown-menu"
              dcjs-toggle-menu={JS.toggle_class("expanded")}
              dcjs-hide-menu={JS.remove_class("expanded")}
            >
              <.link phx-click={JS.dispatch("setLocale", detail: %{locale: "en"})}>
                <li class="menu-item">
                  English
                </li>
              </.link>
              <.link phx-click={JS.dispatch("setLocale", detail: %{locale: "es"})}>
                <li class="menu-item">
                  Español
                </li>
              </.link>
            </ul>
          </li>

          <li
            :if={Application.fetch_env!(:dpul_collections, :feature_account_toolbar)}
            id="account-nav"
          >
            <button
              class="submenu"
              name={gettext("My Account")}
              aria-label={gettext("My Account")}
              aria-expanded="false"
              aria-haspopup="true"
              phx-click={
                JS.toggle_attribute({"aria-expanded", "false", "true"})
                |> JS.toggle_class("expanded", to: "#account-menu")
                |> JS.exec("dcjs-toggle-menu", to: "#account-menu")
              }
              phx-click-away={
                JS.set_attribute({"aria-expanded", "false"})
                |> JS.remove_class("expanded", to: "#account-menu")
                |> JS.exec("dcjs-hide-menu", to: "#account-menu")
              }
            >
              <span class="hover:link-hover font-normal sm:font-medium text-sm sm:text-md cursor-pointer">
                {gettext("My Account")}&nbsp;<span class="font-normal">&gt;</span>
              </span>
            </button>
            <ul
              id="account-menu"
              class="dropdown-menu"
              dcjs-toggle-menu={JS.toggle_class("expanded")}
              dcjs-hide-menu={JS.remove_class("expanded")}
            >
              <%= if @current_scope do %>
                <.link href={~p"/users/settings"}>
                  <li class="menu-item">
                    Settings
                  </li>
                </.link>
                <.link href={~p"/users/log-out"} method="delete">
                  <li class="menu-item">
                    Log out
                  </li>
                </.link>
              <% else %>
                <.link href={~p"/users/log-in"}>
                  <li class="menu-item">
                    Log in
                  </li>
                </.link>
              <% end %>
            </ul>
          </li>
        </ul>
      </nav>
    </header>
    """
  end
end

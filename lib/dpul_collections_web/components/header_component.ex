# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.HeaderComponent do
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  import DpulCollectionsWeb.Gettext

  def header(assigns) do
    ~H"""
    <header class="flex flex-row gap-10 items-center bg-dark-blue py-6 header-x-padding font-poppins">
      <div class="logo flex-none w-32 sm:w-40">
        <img src={~p"/images/pul-logo.svg"} alt="Princeton University Library Logo" />
      </div>
      <div class="app_name flex-1 text-center">
        <.link
          navigate={~p"/"}
          class="sm:inline-block text-4xl uppercase font-bold text-center text-sage"
        >
          {gettext("Digital Collections")}
        </.link>
      </div>
      <div class="menu flex-none w-32 sm:w-40 text-right">
        <div class="dropdown relative inline-block">
          <button
            id="dropdownButton"
            class="text-white hover:link-hover"
            aria-haspopup="true"
            aria-expanded="false"
            phx-click={JS.toggle(to: "#dropdownMenu")}
          >
            {gettext("Language")}
          </button>
          <ul
            id="dropdownMenu"
            phx-click-away={JS.hide(to: "#dropdownMenu")}
            class="dropdown-menu aria-hidden hidden absolute left-auto right-0 list-none bg-white w-150 py-2 px-0 mt-2 shadow-md rounded-md"
            role="menu"
            aria-hidden="true"
          >
            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
              <div phx-click={JS.dispatch("setLocale", detail: %{locale: "en"})}>English</div>
            </li>
            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
              <div phx-click={JS.dispatch("setLocale", detail: %{locale: "es"})}>Español</div>
            </li>
            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
              <div phx-click={JS.dispatch("setLocale", detail: %{locale: "pt-BR"})}>
                Português do Brasil
              </div>
            </li>
          </ul>
        </div>
      </div>
    </header>
    """
  end
end

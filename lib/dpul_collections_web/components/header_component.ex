# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.HeaderComponent do
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def header(assigns) do
    ~H"""
    <header class="flex flex-row gap-10 items-center bg-brand header-y-padding header-x-padding">
      
    <!-- logo -->
      <.link href="https://library.princeton.edu">
        <div class="logo flex-none w-9 sm:hidden">
          <img src={~p"/images/local-svgs.svg"} alt={gettext("Princeton University Library Logo")} />
        </div>
        <div class="logo flex-none sm:w-32 md:w-40 hidden sm:flex">
          <img src={~p"/images/pul-logo.svg"} alt={gettext("Princeton University Library Logo")} />
        </div>
      </.link>
      
    <!-- title -->
      <div class="app_name flex-1 w-auto text-center px-2">
        <.link
          navigate={~p"/"}
          class="text-lg sm:text-xl md:text-2xl lg:text-3xl sm:inline-block uppercase tracking-widest font-bold text-center"
        >
          {gettext("Digital Collections")}
        </.link>
      </div>
      
    <!-- language -->
      <nav
        id="language-nav"
        class="menu flex flex-none justify-end w-10 sm:w-32 md:w-40"
        aria-label={gettext("Main Navigation")}
        dcjs-toggle-menu={JS.toggle(to: {:inner, "ul[role='menu']"})}
        dcjs-hide-menu={JS.hide(to: {:inner, "ul[role='menu']"})}
      >
        <ul
          class="dropdown relative inline-block"
          dcjs-toggle-menu={JS.toggle(to: {:inner, "ul"})}
          dcjs-hide-menu={JS.hide(to: {:inner, "ul"})}
        >
          <li>
            <button
              name={gettext("Language")}
              class="text-white hover:link-hover font-medium"
              aria-label={gettext("Language")}
              aria-expanded="false"
              aria-haspopup="true"
              phx-click={
                JS.toggle_attribute({"aria-expanded", "false", "true"})
                |> JS.exec("dcjs-toggle-menu", to: {:closest, "ul"})
              }
              phx-click-away={
                JS.set_attribute({"aria-expanded", "false"})
                |> JS.exec("dcjs-hide-menu", to: {:closest, "ul"})
              }
            >
              <span class="hover:link-hover font-normal sm:font-medium text-sm sm:text-md cursor-pointer">
                {gettext("Language")}&nbsp;<span class="font-normal">&gt;</span>
              </span>
            </button>
            <ul class="dropdown-menu hidden absolute left-auto right-0 list-none bg-white min-w-3xs py-2 px-0 mt-2 shadow-md rounded-md z-100">
              <li class="p-2 hover:bg-stone-200 focus:bg-stone-200 cursor-pointer">
                <.link phx-click={JS.dispatch("setLocale", detail: %{locale: "en"})}>English</.link>
              </li>
              <li class="p-2 hover:bg-stone-200 focus:bg-stone-200 cursor-pointer">
                <.link phx-click={JS.dispatch("setLocale", detail: %{locale: "es"})}>Español</.link>
              </li>
            </ul>
          </li>
        </ul>
      </nav>
    </header>
    """
  end
end

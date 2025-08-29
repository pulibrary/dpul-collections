# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.HeaderComponent do
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def header(assigns) do
    ~H"""
    <header class="flex bg-brand items-center justify-center border-b-1 border-princeton-orange-on-black">
      <div class="max-w-[1440px] w-full h-full flex flex-row gap-10 items-center bg-brand py-4 header-x-padding">
        <!-- logo -->
        <div class="grid auto-cols-max grid-flow-col flex-grow gap-4 items-center">
          <.link href="https://library.princeton.edu">
            <div class="logo w-9 sm:hidden">
              <img
                src={~p"/images/local-svgs.svg"}
                alt={gettext("Princeton University Library Logo")}
              />
            </div>
            <div class="logo sm:w-32 md:w-40 hidden sm:flex">
              <img src={~p"/images/pul-logo.svg"} alt={gettext("Princeton University Library Logo")} />
            </div>
          </.link>
          <!-- title -->
          <div class="h-full pl-4 border-white border-l-[1px] justify-self-start app_name">
            <.link
              navigate={~p"/"}
              class="text-[24px] sm:inline-block tracking-widest font-semibold text-center"
            >
              {gettext("Digital Collections")}
            </.link>
          </div>
        </div>
        
    <!-- language -->
        <nav
          class="menu flex flex-grow justify-end w-10 sm:w-32 md:w-40"
          aria-label={gettext("Language menu")}
        >
          <div class="dropdown relative inline-block">
            <button
              id="dropdownButton"
              name={gettext("Language")}
              class="text-white hover:link-hover font-medium"
              aria-haspopup="true"
              aria-expanded="false"
              phx-click={JS.toggle(to: "#dropdownMenu")}
            >
              <span class="hover:link-hover font-normal sm:font-medium text-sm sm:text-md cursor-pointer">
                {gettext("Language")}&nbsp;<span class="font-normal">&gt;</span>
              </span>
            </button>
            <ul
              id="dropdownMenu"
              phx-click-away={JS.hide(to: "#dropdownMenu")}
              class="dropdown-menu aria-hidden hidden absolute left-auto right-0 list-none bg-white min-w-3xs py-2 px-0 mt-2 shadow-md rounded-md z-100"
              role="menu"
              aria-hidden="true"
            >
              <li
                role="menuitem"
                tabindex="-1"
                class="p-2 hover:bg-stone-200 focus:bg-stone-200 cursor-pointer"
              >
                <div phx-click={JS.dispatch("setLocale", detail: %{locale: "en"})}>English</div>
              </li>
              <li
                role="menuitem"
                tabindex="-1"
                class="p-2 hover:bg-stone-200 focus:bg-stone-200 cursor-pointer"
              >
                <div phx-click={JS.dispatch("setLocale", detail: %{locale: "es"})}>Español</div>
              </li>
            </ul>
          </div>
        </nav>
      </div>
    </header>
    """
  end
end

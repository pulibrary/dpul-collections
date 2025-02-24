# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.HeaderComponent do
    use DpulCollectionsWeb, :html
    import DpulCollectionsWeb.Gettext
  
    def header(assigns) do
      ~H"""
      <header class="flex flex-row gap-10 items-center bg-gray-700 px-6 py-6 sm:py-10 sm:px-8 lg:px-10">
            <div class="logo flex-none w-32 sm:w-60">
                <img src={~p"/images/pul-logo.svg"} alt="Princeton University Library Logo" />
            </div>
            <div class="app_name flex-1">
                <.link navigate={~p"/"} class="text-2xl hidden sm:inline-block text-white hover:underline hover:underline-offset-8 hover:decoration-orange-500 hover:decoration-2">
                    <%= gettext("Digital Collections") %>
                </.link>
            </div>
            <div class="menu flex-none">
                <div class="dropdown relative inline-block">
                    <button id="dropdownButton" 
                        class="text-white hover:underline hover:underline-offset-8 hover:decoration-orange-500 hover:decoration-2" 
                        aria-haspopup="true" 
                        aria-expanded="false"
                        phx-click={JS.toggle(to: "#dropdownMenu")}>
                        <%= gettext("Language") %>
                    </button>
                    <ul id="dropdownMenu" 
                        phx-click-away={JS.hide(to: "#dropdownMenu")}
                        class="dropdown-menu aria-hidden hidden absolute left-auto right-0 list-none bg-white w-150 py-2 px-0 mt-2 shadow-md rounded-md" role="menu" aria-hidden="true">
                        <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                            <a href="?locale=en">English</a>
                        </li>
                        <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                            <a href="?locale=es">Español</a>
                        </li>
                        <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                            <a href="?locale=pt-BR">Português do Brasil</a>
                        </li>
                    </ul>
                </div>
            </div>
        </header>
      """
    end
  end
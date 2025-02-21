# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.HeaderComponent do
    use DpulCollectionsWeb, :html
    import DpulCollectionsWeb.Gettext
  
    def header(assigns) do
      ~H"""
      <header class="flex flex-row gap-10 bg-violet-100 py-10 px-8 lg:px-10">
                <div class="logo flex-none">Logo</div>
            <div class="app_name flex-1"><.link navigate={~p"/"}>DPUL Collections</.link></div>
            <div class="menu flex-none">
                <div class="dropdown relative inline-block">
                    <button id="dropdownButton" 
                        aria-haspopup="true" 
                        aria-expanded="false"
                        phx-click={JS.toggle(to: "#dropdownMenu")}>
                        <%= gettext("Language") %>
                    </button>
                    <ul id="dropdownMenu" class="dropdown-menu aria-hidden hidden absolute list-none bg-white w-150 p-0 m-0" role="menu" aria-hidden="true">
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
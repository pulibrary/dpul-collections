defmodule DpulCollectionsWeb.HeaderComponent do 
    use DpulCollectionsWeb, :live_component 
    import DpulCollectionsWeb.Gettext
    alias Phoenix.LiveView.JS 

    def render(assigns) do 
        ~H"""
        <header class="flex flex-row gap-10 bg-violet-100 py-10 px-8 lg:px-10">
            <div class="logo flex-none">Logo</div>
            <div class="app_name flex-1">DPUL Collections</div>
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
                            <.link phx-click="language-english" phx-target={@myself} >English</.link>
                        </li>
                        <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                            <.link phx-click="language-spanish" phx-target={@myself}>Español</.link>
                        </li>
                        <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                            <a href="#">Português do Brasil</a>
                        </li>
                    </ul>
                </div>
            </div>
        </header>
        """
    end

    def handle_event("language-english", _map, socket) do 
        Gettext.put_locale(DpulCollectionsWeb.Gettext, "en")
        {:noreply, Phoenix.Component.assign(socket, :locale, "en")}
    end

    def handle_event("language-spanish", _map, socket) do 
        Gettext.put_locale(DpulCollectionsWeb.Gettext, "es")
        {:noreply, Phoenix.Component.assign(socket, :locale, "es")}
    end

end 
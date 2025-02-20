defmodule DpulCollectionsWeb.LayoutComponent do 
    use DpulCollectionsWeb, :live_component 
    import DpulCollectionsWeb.Gettext
    alias Phoenix.LiveView.JS 

    def mount(_params, _session, socket) do
        {:ok, assign(socket, :live_view_pid, self())}
    end

    def render(assigns) do 
        ~H"""
        <div class="flex flex-col min-h-screen" id="app">
            <header class="flex flex-row gap-10 bg-violet-100 py-10 px-8 lg:px-10">
                <div class="logo flex-none">Logo</div>
                <div class="app_name flex-1">DPUL Collections</div>
                <div class="menu flex-none">
                    <div class="dropdown relative inline-block">
                        <button id="dropdownButton" 
                            aria-haspopup="true" 
                            aria-expanded="false"
                            phx-click={JS.toggle(to: "#dropdownMenu")}>
                            <%= gettext("Language", locale: @locale) %>
                        </button>
                        <ul id="dropdownMenu" class="dropdown-menu aria-hidden hidden absolute list-none bg-white w-150 p-0 m-0" role="menu" aria-hidden="true">
                            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                                <.link phx-click="set-locale" phx-value-locale="en">English</.link>
                            </li>
                            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                                <.link phx-click="set-locale" phx-value-locale="es">Español</.link>
                            </li>
                            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
                                <a href="#">Português do Brasil</a>
                            </li>
                        </ul>
                    </div>
                </div>
            </header>
              <div class="flex-1">
                    <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
                    <.flash_group flash={@flash} />
                    <%= render_slot(@inner_block) %>
                    </main>
                </div>
                <%= DpulCollectionsWeb.LuxComponents.footer(assigns) %>
        </div>
        """
    end

    def handle_event("set-locale", %{"locale" => locale}, socket) do
        IO.puts("Sending message to parent LiveView #{inspect(socket.assigns.live_view_pid)}")
    
        send(socket.assigns.live_view_pid, {:set_locale, locale})
        {:noreply, socket}
    end

end 
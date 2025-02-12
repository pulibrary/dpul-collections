defmodule DpulCollectionsWeb.HeaderComponent do 
    use DpulCollectionsWeb, :live_component 

    def render(assigns) do 
        ~H"""
        <header class="flex flex-row gap-10 bg-violet-100 py-10 px-8 lg:px-10">
            <div class="logo flex-none">Logo</div>
            <div class="app_name flex-1">DPUL Collections</div>
            <div class="menu flex-none">Menu</div>
        </header>
        """
    end

end 
defmodule DpulCollectionsWeb.HeaderComponent do 
    use DpulCollectionsWeb, :live_component 

    def render(assigns) do 
        ~H"""
        <header>
        hello world!
        </header>
        """
    end

end 
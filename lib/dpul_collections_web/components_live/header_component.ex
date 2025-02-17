defmodule DpulCollectionsWeb.HeaderComponent do
  use DpulCollectionsWeb, :live_component
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <header class="flex flex-row gap-10 bg-violet-100 py-10 px-8 lg:px-10">
      <div class="logo flex-none">Logo</div>
      <div class="app_name flex-1">DPUL Collections</div>
      <div class="menu flex-none">
        <div class="dropdown relative inline-block">
          <button
            id="dropdownButton"
            aria-haspopup="true"
            aria-expanded="false"
            phx-click={toggle_dropdown("#dropdownMenu")}
          >
            Language
          </button>
          <ul
            id="dropdownMenu"
            class="dropdown-menu aria-hidden hidden absolute list-none bg-white w-150 p-0 m-0"
            role="menu"
            aria-hidden="true"
          >
            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
              <a href="#">English</a>
            </li>
            <li role="menuitem" tabindex="-1" class="p-2 hover:bg-stone-200 focus:bg-stone-200">
              <a href="#">Español</a>
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

  defp toggle_dropdown(id, js \\ %JS{}) do
    js
    |> JS.toggle(to: id)
  end
end

defmodule DpulCollectionsWeb.LuxComponents do
  use Phoenix.Component
  import DpulCollectionsWeb.Gettext

  def header(assigns) do
    ~H"""
    <lux-library-header
      app-name="Digital Collections"
      abbr-name="Collections"
      app-url="/"
      theme="shade"
    >
      <lux-menu-bar
        type="main-menu"
        v-bind:menu-items={"[
        {name: '#{gettext("Language")}', component: 'Language', children: [
          {name: 'English', component: 'English', href: '?locale=en'},
          {name: 'Español', component: 'Español', href: '?locale=es'},
          {name: 'Português do Brasil', component: 'Português do Brasil', href: '?locale=pt-BR'}
        ]}
      ]"}
        theme="shade"
      />
    </lux-library-header>
    """
  end

  def footer() do
    ~S"""
    <lux-university-footer class="text-center" type="footer" theme="shade"></lux-university-footer>
    """
  end
end

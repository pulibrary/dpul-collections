defmodule DpulCollectionsWeb.LuxComponents do
  use Phoenix.Component

  def header() do
    ~S"""
    <lux-library-header app-name="Digital Collections" abbr-name="Collections" app-url="https://library.princeton.edu/" theme="dark">
      <lux-menu-bar type="main-menu" :menu-items="[
        {name: 'Language', component: 'Language', children: [
          {name: 'English', component: 'English', href: '?locale=en'},
          {name: 'Español', component: 'Español', href: '?locale=es'},
          {name: 'Português do Brasil', component: 'Português do Brasil', href: '?locale=pt-BR'}
        ]}
      ]"/>
    </lux-library-header>
    """
  end

  def footer() do
    ~S"""
    <lux-library-footer type="footer"></lux-library-footer>
    """
  end
end

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

  def footer(assigns) do
    ~H"""
    <lux-university-footer
      class="text-center"
      type="footer"
      theme="shade"
      v-bind:links={"[
      {text: '#{gettext("Copyright Policy")}', href: 'https://library.princeton.edu/about/policies/copyright-and-permissions-policies'}, 
      {text: '#{gettext("Privacy Notice")}', href: 'https://www.princeton.edu/privacy-notice'}, 
      {text: '#{gettext("Accessibility Help")}', href: 'https://accessibility.princeton.edu/help'}
    ]"}
    >
    </lux-university-footer>
    """
  end
end

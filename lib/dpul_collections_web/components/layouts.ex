defmodule DpulCollectionsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DpulCollectionsWeb, :html
  use Gettext, backend: DpulCollectionsWeb.Gettext

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :content_class, :list, default: ["bg-background", "page-y-padding"]
  attr :display_title, :boolean, default: true

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    {DpulCollectionsWeb.HeaderComponent.header(assigns)}
    <!-- "relative" here lets us have absolute layout elements that cover all parts of the page except the header. -->
    <div class="relative flex-1 flex flex-col">
      <div class="flex-1 bg-background">
        <.live_component module={DpulCollectionsWeb.SearchBarComponent} id="search-bar" />
        <main id="main-content" class={@content_class}>
          <.flash_group flash={@flash} />
          {render_slot(@inner_block)}
        </main>
      </div>
      {DpulCollectionsWeb.FooterComponent.footer(assigns)}
    </div>
    """
  end
end

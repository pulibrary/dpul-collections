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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.live_component module={DpulCollectionsWeb.SearchBarComponent} id="search-bar" />
    <main id="main-content" class={@content_class}>
      <.flash_group flash={@flash} />
      {render_slot(@inner_block)}
    </main>
    """
  end
end

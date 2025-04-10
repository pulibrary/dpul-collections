defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}
  alias DpulCollectionsWeb.Live.Helpers

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        item_count: Solr.document_count(),
        q: nil,
        recent_items:
          Solr.recently_digitized(5)["docs"]
          |> Enum.map(&Item.from_solr(&1))
      )

    {:ok, socket,
     temporary_assigns: [item_count: nil], layout: {DpulCollectionsWeb.Layouts, :home}}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-flow-row auto-rows-max gap-20">
      <div class="recent-items grid-row bg-cloud">
        <div class="content-area">
          <div class="page-t-padding" />
          <h1>{gettext("Recently Added Items")}</h1>
          <div class="grid grid-cols-5 gap-6 pt-5">
            <DpulCollectionsWeb.BrowseLive.browse_item :for={item <- @recent_items} item={item} />
          </div>
        </div>
        <div class="page-b-padding" />
      </div>
    </div>
    """
  end
end

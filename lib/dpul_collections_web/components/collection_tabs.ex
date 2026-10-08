defmodule DpulCollectionsWeb.CollectionTabs do
  use DpulCollectionsWeb, :html
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollectionsWeb.Live.Helpers

  def featured_and_related(assigns) do
    ~H"""
    <div>
      <.content_separator />
      <div class="content-area">
        <div
          :if={has_featured?(@collection) && has_related?(@collection)}
          class="tab-bar flex flex-row"
          role="tablist"
        >
          <.tab_button
            :if={has_featured?(@collection) && has_related?(@collection)}
            id="featured-items-tab"
            label={gettext("Featured Highlights")}
            pane="featured-items-container"
            active?={true}
          />
          <.tab_button
            :if={has_featured?(@collection) && has_related?(@collection)}
            id="related-collections-tab"
            label={gettext("Related Collections")}
            pane="related-collections-container"
            active?={false}
          />
        </div>
        <div class="grid">
          <div
            :if={has_featured?(@collection)}
            id="featured-items-container"
            phx-update="ignore"
            role="tabpanel"
            class={[
              "col-start-1 row-start-1 grid-flow auto-rows-max tab-content"
            ]}
          >
            <.card_row
              id="featured-items"
              title={gettext("Featured Highlights")}
              hide_title?={has_related?(@collection)}
              layout="content-area"
              color=""
              arrow_theme="light"
            >
              <.item_browse_card_li
                :for={item <- @collection.featured_items}
                show_images={[]}
                item={item}
                current_scope={@current_scope}
                current_path={@current_path}
              />
            </.card_row>
          </div>
          <div
            :if={has_related?(@collection)}
            id="related-collections-container"
            role="tabpanel"
            phx-update="ignore"
            class={[
              "col-start-1 row-start-1 grid-flow auto-rows-max tab-content",
              has_featured?(@collection) && "hidden"
            ]}
          >
            <.card_row
              id="related-collections"
              layout="content-area"
              title={gettext("Related Collections")}
              hide_title?={has_featured?(@collection)}
              more_link={
                Helpers.search_path(%{filter: %{related_collections: @collection.title |> hd}})
              }
              color=""
              arrow_theme="light"
            >
              <.collection_card_li
                :for={item <- @collection.related_collections}
                collection={item}
              />
            </.card_row>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def tab_button(assigns) do
    ~H"""
    <button
      phx-click={
        set_active_tab("##{@id}")
        |> show_active_content("##{@pane}")
      }
      role="tab"
      id={@id}
      class={[
        "tab",
        "tab-base",
        "no-underline",
        "text-wrap",
        @active? && "tab-active"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp set_active_tab(js \\ %JS{}, tab) do
    js
    |> JS.remove_class("tab-active", to: "button.tab-active")
    |> JS.add_class("tab-active", to: tab)
  end

  defp show_active_content(js, to) do
    js
    |> JS.hide(
      transition: {"ease-out duration-300", "opacity-100", "opacity-0"},
      to: "div.tab-content"
    )
    |> JS.show(transition: {"ease-in duration-300", "opacity-0", "opacity-100"}, to: to)
  end

  defp has_featured?(collection) do
    length(collection.featured_items) > 0
  end

  defp has_related?(collection) do
    length(collection.related_collections) > 0
  end
end

defmodule DpulCollectionsWeb.UserSetsLive.Show do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.UserSets
  alias DpulCollections.Solr
  alias DpulCollections.Item
  import DpulCollectionsWeb.BrowseItem

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => set_id}, _uri, socket) do
    user_set = UserSets.get_set(set_id)

    items =
      user_set.set_items
      |> Enum.map(&Solr.find_by_id(&1.solr_id))
      |> Enum.map(&Item.from_solr/1)

    {:noreply, socket |> assign(user_set: user_set, items: items)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="user_set" class="content-area flex flex-col gap-6">
        <h1>{gettext("Item Set")}</h1>
        <hr />
        <h2>{length(@user_set.set_items)} Items</h2>
        <ul id="set-items" class="grid grid-cols-[repeat(auto-fit,minmax(300px,_1fr))] gap-6 pt-5">
          <.browse_li
            :for={item <- @items}
            show_images={@show_images}
            item={item}
            added?={false}
            likeable?={false}
            current_scope={@current_scope}
          />
        </ul>
      </div>
    </Layouts.app>
    """
  end
end

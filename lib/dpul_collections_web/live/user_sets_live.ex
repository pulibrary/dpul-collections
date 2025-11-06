defmodule DpulCollectionsWeb.UserSetsLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.UserSets
  alias DpulCollections.Solr
  alias DpulCollections.Item
  import DpulCollectionsWeb.BrowseItem

  def mount(_params, _session, socket) do
    sets_with_items =
      UserSets.list_user_sets(socket.assigns.current_scope)
      |> Enum.map(&set_item_tuple(&1))

    {:ok,
     socket
     |> assign(:sets_with_items, sets_with_items)}
  end

  defp set_item_tuple(set) do
    {set,
     set.set_items
     |> first_item()}
  end

  defp first_item([item | _]) do
    item
    |> Map.fetch!(:solr_id)
    |> Solr.find_by_id()
    |> Item.from_solr()
  end

  defp first_item([]) do
    Item.null_item()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="browse" class="content-area">
        <h1>{gettext("My Sets")}</h1>
        <ul class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 pt-5">
          <.card_li
            :for={{set, item} <- @sets_with_items}
            id_prefix="set"
            target_item={set}
            thumb_source={item}
            show_small_thumbs?={false}
            show_images={@show_images}
            current_scope={@current_scope}
            url={~p"/sets/#{set.id}"}
          >
            <:extra_info>
              {set.description}
            </:extra_info>
          </.card_li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end

defmodule DpulCollectionsWeb.UserSetsLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.UserSets
  alias DpulCollections.Solr
  alias DpulCollections.Item
  alias DpulCollections.UserSets.Set
  import DpulCollectionsWeb.BrowseItem

  def mount(_params, _session, socket) do
    UserSets.subscribe_user_sets(socket.assigns.current_scope)

    {:ok, socket |> reload_sets_with_items()}
  end

  # One of the user's sets got updated, reload them all.
  def handle_info({_, %Set{}}, socket) do
    {:noreply, socket |> reload_sets_with_items()}
  end

  defp reload_sets_with_items(socket) do
    sets_with_items =
      UserSets.list_user_sets(socket.assigns.current_scope)
      |> Enum.map(&set_item_tuple(&1))

    socket
    |> assign(:sets_with_items, sets_with_items)
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
    <Layouts.app flash={@flash} current_path={@current_path} current_scope={@current_scope}>
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
            <:card_buttons>
              <.card_button
                phx-click="delete_set"
                phx-value-set-id={set.id}
                data-confirm={gettext("Are you sure you want to delete this?")}
                icon="hero-trash"
                label={gettext("Delete")}
              />
            </:card_buttons>
            <:extra_info>
              {set.description}
            </:extra_info>
          </.card_li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  def handle_event(
        "delete_set",
        %{"set-id" => set_id},
        socket = %{assigns: %{current_scope: current_scope}}
      ) do
    set = UserSets.get_set!(current_scope, set_id)

    {:ok, _} = UserSets.delete_set(current_scope, set)

    {
      :noreply,
      socket
      |> Phoenix.LiveView.put_flash(
        :info,
        gettext("Deleted %{set_title}.", %{set_title: set.title})
      )
    }
  end
end

defmodule DpulCollectionsWeb.UserSetsLive.Show do
  alias DpulCollections.UserSets.Set
  alias DpulCollectionsWeb.ItemLive
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.UserSets
  alias DpulCollections.Solr
  alias DpulCollections.Item
  import DpulCollectionsWeb.BrowseItem

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_info({:updated, %Set{id: id}}, socket = %{assigns: %{user_set: %{id: id}}}) do
    handle_params(%{"id" => id}, nil, socket)
  end

  def handle_params(%{"id" => set_id}, _uri, socket) do
    user_set = UserSets.get_set(set_id)
    UserSets.subscribe_set(user_set)

    items =
      user_set.set_items
      |> Enum.map(&Solr.find_by_id(&1.solr_id))
      |> Enum.map(&Item.from_solr/1)

    {:noreply, socket |> assign(user_set: user_set, items: items)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="user-set" class="content-area flex flex-col gap-6">
        <div id="metadata" class="flex flex-col gap-2">
          <span class="text-xl uppercase tracking-wide">
            {gettext("Item Set")}
          </span>
          <h1
            :if={@current_scope && @user_set.user_id == @current_scope.user.id}
            class="text-4xl font-bold normal-case"
            dir="auto"
          >
            {@user_set.title}
          </h1>
          <div
            :if={@current_scope && @user_set.user_id == @current_scope.user.id}
            id="set-description"
            dir="auto"
          >
            {@user_set.description}
          </div>
        </div>
        <div id="user-set-actions" class="flex inline-flex">
          <.secondary_button
            class="text-md px-3 py-2 flex gap-2 h-10"
            phx-click={JS.exec("dcjs-open", to: "#share-modal")}
          >
            <.icon name="hero-share" /> Share
          </.secondary_button>
          <ItemLive.share_modal
            path={~p"/sets/#{@user_set.id}"}
            id="share-modal"
            heading={gettext("Share this set")}
          />
        </div>
        <hr />
        <h2>{length(@user_set.set_items)} Items</h2>
        <ul id="set-items" class="grid grid-cols-[repeat(auto-fill,minmax(300px,_1fr))] gap-12 pt-5">
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

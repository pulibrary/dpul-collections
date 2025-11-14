defmodule DpulCollectionsWeb.BrowseLive do
  alias DpulCollectionsWeb.SearchLive.SearchState
  alias DpulCollectionsWeb.BrowseItem
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        items: [],
        liked_items: [],
        page_title: gettext("Browse - Digital Collections"),
        seed: nil,
        focused_item: nil,
        focused_id: nil,
        current_path: nil
      )

    {:ok, socket}
  end

  @spec handle_params(nil | maybe_improper_list() | map(), any(), any()) :: {:noreply, any()}
  # If we've been asked to randomize, do it.
  def handle_params(%{"r" => given_seed}, _url, %{assigns: %{seed: stored_seed}} = socket) do
    if given_seed != stored_seed do
      socket =
        socket
        |> assign(
          items:
            Solr.random(90, given_seed)["docs"]
            |> Enum.map(&Item.from_solr(&1)),
          seed: given_seed,
          focused_item: nil,
          focused_id: nil
        )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # If we're recommending items based on another item, do that.
  def handle_params(
        %{"focus_id" => focus_id},
        _uri,
        %{assigns: %{focused_id: existing_focus}} = socket
      ) do
    # Only update the focus if we're focusing a new one.
    if focus_id != existing_focus do
      item = Solr.find_by_id(focus_id) |> Item.from_solr()
      # In this view we're going to use one of the spots to show the focused item,
      # so only get 89 random
      recommended_items =
        Solr.related_items(item, SearchState.from_params(%{}), 89)["docs"]
        |> Enum.map(&Item.from_solr/1)

      liked_items =
        cond do
          item.id in Enum.map(socket.assigns.liked_items, fn item -> item.id end) ->
            socket.assigns.liked_items

          # When we come to this link directly liked_items is empty - add the one
          # we're focusing.
          true ->
            [item | socket.assigns.liked_items]
        end

      {:noreply,
       socket
       |> assign(
         seed: nil,
         items: recommended_items,
         focused_item: item,
         liked_items: liked_items,
         focused_id: focus_id
       )}
    else
      {:noreply, socket}
    end
  end

  # If neither, generate a random seed and display random items.
  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}", replace: true)}
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_scope={@current_scope}>
      <div id="browse" class="content-area">
        <h1 id="browse-header" class="mb-2">{gettext("Browse")}</h1>
        <div class="mb-5 text-lg w-full items-center">
          <div :if={!@focused_item} class="mb-5">
            {gettext("Exploring a random set of items from our collections.")}
          </div>
          <h3 :if={@focused_item}>
            {gettext("Exploring items similar to")}
            <.link href={@focused_item.url} class="font-semibold text-accent" target="_blank">
              {@focused_item.title}
            </.link>
          </h3>
        </div>
        <.display_items {assigns} />
      </div>
    </Layouts.app>
    """
  end

  def display_items(assigns) do
    ~H"""
    <div>
      <.liked_items {assigns} />
      <ul id="browse-items" class="grid grid-cols-[repeat(auto-fit,minmax(300px,_1fr))] gap-6 pt-5">
        <.browse_li
          :if={@focused_item}
          item={@focused_item}
          likeable?={false}
          target="_blank"
          class="border-6 border-primary"
          show_images={@show_images}
          current_scope={@current_scope}
          current_path={@current_path}
        />
        <.browse_li
          :for={item <- @items}
          item={item}
          target="_blank"
          show_images={@show_images}
          current_scope={@current_scope}
          current_path={@current_path}
        />
      </ul>
    </div>
    """
  end

  def liked_items(assigns) do
    ~H"""
    <div class="sticky top-0 left-0 z-10 flex w-full justify-end pointer-events-none">
      <div
        id="liked-items"
        class="pointer-events-auto inline-flex max-w-full items-center rounded-bl-lg bg-background p-2 drop-shadow-2xl"
      >
        <div class="flex items-center overflow-y-hidden overflow-x-auto">
          <.link
            :for={item <- @liked_items}
            phx-click={JS.dispatch("dpulc:scrollTop")}
            patch={~p"/browse/focus/#{item.id}"}
            class={[
              "liked-item h-[64px] w-[64px] flex-shrink-0 mx-1 last:mr-2",
              @focused_item && item.id == @focused_item.id &&
                "rounded-md border-4 border-accent h-[84px] w-[84px]"
            ]}
          >
            <BrowseItem.thumb
              thumb={BrowseItem.thumbnail_service_url(item)}
              item={item}
              show_images={@show_images}
            />
          </.link>
        </div>

        <div class="flex-none">
          <.primary_button
            phx-click={JS.push("randomize") |> JS.dispatch("dpulc:scrollTop")}
            class={[
              "rounded-md h-[64px] w-[64px] flex flex-col justify-center text-xs p-1 hover:no-underline",
              @focused_item == nil && "rounded-md border-4 border-accent h-[84px] w-[84px]"
            ]}
            aria-label={gettext("View Random Items")}
          >
            <.icon name="ion:dice" class="h-8 w-8" /> {gettext("Random")}
          </.primary_button>
        </div>
      </div>
    </div>
    """
  end
end

defmodule DpulCollectionsWeb.BrowseLive do
  alias DpulCollections.Classifier
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
        page_title: "Browse - Digital Collections",
        focused_item: nil,
        auto_subjects: nil,
        auto_genres: nil
      )

    {:ok, socket}
  end

  @spec handle_params(nil | maybe_improper_list() | map(), any(), any()) :: {:noreply, any()}
  # If we've been asked to randomize, do it.
  def handle_params(%{"r" => given_seed}, _uri, socket) do
    socket =
      socket
      |> assign(
        items:
          Solr.random(90, given_seed)["docs"]
          |> Enum.map(&Item.from_solr(&1)),
        focused_item: nil,
        auto_subjects: nil,
        auto_genres: nil
      )

    {:noreply, socket}
  end

  # If we're recommending items based on another item, do that.
  def handle_params(%{"focus_id" => focus_id}, _uri, socket) do
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
     socket |> assign(auto_subjects: nil, auto_genres: nil, items: recommended_items, focused_item: item, liked_items: liked_items)}
  end

  # If neither, generate a random seed and display random items.
  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}", replace: true)}
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}")}
  end

  def handle_event("search", %{"q" => search_query}, socket) do
    %{subjects: subjects, genres: genres} = DpulCollections.Classifier.get_top_subjects(search_query)
    subjects = Enum.filter(subjects, fn({score, _label}) -> score > 0.45 end)
    genres = Enum.filter(genres, fn({score, _label}) -> score > 0.45 end)
    search_state = DpulCollectionsWeb.SearchLive.SearchState.from_params(%{"per_page" => "100", "q" => [suggest_query("subject_txtm", subjects), suggest_query("genre_txtm", genres)] |> Enum.filter(fn(x) -> x != nil end) |> Enum.join(" ")})
    solr_response = Solr.query(search_state)
    items =
      solr_response["docs"]
      |> Enum.map(&Item.from_solr(&1))
    socket =
      socket
      |> assign(items: items, auto_subjects: Enum.map(subjects, fn({_score, s}) -> s end), auto_genres: Enum.map(genres, fn({_score, s}) -> s end))
    {:noreply, socket}
  end

  def suggest_query(_, []), do: nil
  def suggest_query(field, matches) do
    "#{field}:(#{matches |> weight_matches |> Enum.join(" OR ")})"
  end

  def weight_matches(matches) do
    Enum.map(matches, fn({score, value}) ->
      cond do
        score > 0.65 -> "'#{value}'^4"
        score > 0.6 -> "'#{value}'^3"
        score > 0.5 -> "'#{value}'^2"
        true        -> "'#{value}'"
      end
    end)
  end

  def render(assigns) do
    ~H"""
    <div id="browse" class="content-area">
      <h1 id="browse-header" class="mb-2">{gettext("Browse")}</h1>
      <div class="mb-5 text-2xl w-full items-center">
        <div :if={!@focused_item} class="text-2xl mb-5">
          {gettext("Exploring a random set of items from our collections.")}
        </div>
          <form id="search-form" class="w-full h-full bg-secondary p-2 rounded-lg" phx-submit="search">
            <div class="flex items-center w-full h-full" role="search">
              <span class="flex-none">
                <.icon name="hero-sparkles" class="h-8 w-8 icon" />
              </span>
              <label for="q" class="sr-only">{gettext("Tell us what you like and we'll suggest some things. e.g. I want some art I can paint on my wall")}</label>
              <input
                class="m-2 px-1 py-0 grow h-full placeholder:text-dark-text/40 bg-transparent border-none placeholder:text-xl text-xl placeholder:font-bold w-full"
                type="text"
                id="q"
                name="q"
                placeholder={gettext("Tell us what you like and we'll suggest some things. e.g. I want some art I can paint on my wall")}
                dir="auto"
              />
              <button
                id="search-button"
                type="submit"
                class="btn-secondary px-4 h-8 invisible flex-none"
              >
                {gettext("Suggest")}
              </button>
            </div>
          </form>
          <div :if={@auto_subjects} class="text-sm p-2">
            Subjects we picked: {Enum.join(@auto_subjects, ", ")}
          </div>
          <div :if={@auto_genres} class="text-sm p-2">
            Genres we picked: {Enum.join(@auto_genres, ", ")}
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
    """
  end

  def display_items(assigns) do
    ~H"""
    <div>
      <.liked_items {assigns} />
      <div id="browse-items" class="grid grid-cols-[repeat(auto-fit,minmax(300px,_1fr))] gap-6 pt-5">
        <.browse_item
          :if={@focused_item}
          item={@focused_item}
          likeable?={false}
          target="_blank"
          class="border-6 border-primary"
        />
        <.browse_item :for={item <- @items} item={item} target="_blank" />
      </div>
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
            <BrowseItem.thumb thumb={BrowseItem.thumbnail_service_url(item)} />
          </.link>
        </div>

        <div class="flex-none">
          <.primary_button
            phx-click={JS.push("randomize") |> JS.dispatch("dpulc:scrollTop")}
            class={[
              "rounded-md h-[64px] w-[64px] flex flex-col justify-center text-xs p-1 hover:no-underline",
              @focused_item == nil && "rounded-md border-4 border-accent h-[84px] w-[84px]"
            ]}
            aria-label="View Random Items"
          >
            <.icon name="ion:dice" class="h-8 w-8" /> {gettext("Random")}
          </.primary_button>
        </div>
      </div>
    </div>
    """
  end
end

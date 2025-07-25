defmodule DpulCollectionsWeb.SearchComponents do
  use Phoenix.Component
  alias DpulCollections.Solr

  attr :text, :string, doc: "the page number, or ellipsis"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  def page_link_or_span(assigns) do
    ~H"""
    <a :if={@text != "..."} {@rest} href="#" phx-click="paginate" phx-value-page={@text}>
      {@text}
    </a>
    <span :if={@text == "..."} {@rest}>
      {@text}
    </span>
    """
  end
end

defmodule DpulCollectionsWeb.SearchLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.SearchComponents
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}
  use Solr.Constants
  alias DpulCollectionsWeb.Live.Helpers
  alias DpulCollectionsWeb.SearchLive.SearchState

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    search_state = SearchState.from_params(params |> Helpers.clean_params())
    solr_response = Solr.query(search_state)

    items =
      solr_response["docs"]
      |> Enum.map(&Item.from_solr(&1))

    total_items = solr_response["numFound"]

    socket =
      assign(socket,
        page_title: "Search Results - Digital Collections",
        search_state: search_state,
        item_counter: item_counter(search_state, total_items),
        items: items,
        total_items: total_items
      )

    {:noreply, socket}
  end

  defp item_counter(_, 0), do: gettext("No items found")

  defp item_counter(%{page: page, per_page: per_page}, total_items) do
    first_item = max(page - 1, 0) * per_page + 1
    last_page? = page * per_page >= total_items

    last_item =
      cond do
        last_page? -> total_items
        true -> first_item + per_page - 1
      end

    "#{first_item} - #{last_item} #{gettext("of")} #{total_items}"
  end

  def sort_by_params do
    @valid_sort_by
    # Don't include things without labels.
    |> Enum.filter(fn {_, v} -> v[:label] end)
    |> Enum.map(fn {k, v} -> {v[:label], k} end)
  end

  def filter_configuration do
    @filters
  end

  def render(assigns) do
    ~H"""
    <div class="content-area">
      <.results_for_keywords_heading keywords={@search_state.q} />
      <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
        <div id="filters" class="grid md:grid-cols-[auto_300px] gap-2">
          <form
            id="date-filter"
            phx-submit="filter-date"
            class="grid md:grid-cols-[150px_200px_200px_200px] gap-2"
          >
            <label class="col-span-1 self-center font-bold uppercase" for="date-filter">
              {gettext("filter by year")}:
            </label>
            <input
              class="col-span-1"
              type="text"
              placeholder={gettext("From")}
              form="date-filter"
              name="filter[year][from]"
              value={@search_state.filter["year"]["from"]}
            />
            <input
              class="col-span-1"
              type="text"
              placeholder={gettext("To")}
              form="date-filter"
              name="filter[year][to]"
              value={@search_state.filter["year"]["to"]}
            />
            <button class="col-span-1 md:col-span-1 btn-primary" type="submit">
              {gettext("Apply")}
            </button>
          </form>
          <form id="sort-form" class="grid md:grid-cols-[auto_200px] gap-2" phx-change="sort">
            <label class="col-span-1 self-center font-bold uppercase md:text-right" for="sort-by">
              {gettext("sort by")}:
            </label>
            <select class="col-span-1" name="sort-by" aria-label={gettext("sort by")}>
              {Phoenix.HTML.Form.options_for_select(
                sort_by_params(),
                @search_state.sort_by
              )}
            </select>
          </form>
          <form id="filter-pills">
            <div class="my-8 select-none flex flex-wrap gap-4">
              <.filter
                :for={{filter_field, filter_settings} <- filter_configuration()}
                search_state={@search_state}
                field={filter_field}
                label={filter_settings.label}
                filter_value={filter_settings.value_function.(@search_state.filter[filter_field])}
              />
            </div>
          </form>
        </div>
        <div id="item-counter">
          <span>{@item_counter}</span>
        </div>
      </div>
      <div class="grid grid-flow-row auto-rows-max gap-8">
        <div :for={item <- @items}>
          <hr class="mb-8" />
          <.search_item search_state={@search_state} item={item} sort_by={@search_state.sort_by} />
        </div>
      </div>
      <div class="text-center max-w-5xl mx-auto text-lg py-8">
        <.paginator
          page={@search_state.page}
          per_page={@search_state.per_page}
          total_items={@total_items}
        />
      </div>
    </div>
    """
  end

  attr :field, :string, required: true
  attr :filter_value, :string, required: true
  attr :label, :string, required: true
  attr :search_state, :map, required: true

  def filter(assigns) do
    ~H"""
    <.link
      :if={@filter_value}
      role="button"
      id={"#{@field}-filter"}
      navigate={self_route(@search_state, %{filter: %{@field => nil}})}
      class="filter mb-2 focus:border-3 focus:visible:border-rust focus:border-rust py-2 px-4 shadow-md no-underline rounded-lg bg-primary border-dark-blue text-white font-sans font-semibold text-sm btn-primary hover:text-white hover:bg-accent focus:outline-none active:shadow-none"
    >
      {# These labels are defined explicitly in Solr.Constants, but have to be called here because Constants is defined at compile time.}
      {Gettext.gettext(DpulCollectionsWeb.Gettext, @label)}
      <span><.icon name="hero-chevron-right" class="p-1 h-4 w-4 icon" /></span>
      {@filter_value}
      <span><.icon name="hero-x-circle" class="ml-2 h-6 w-6 icon" /></span>
    </.link>
    """
  end

  attr :item, Item, required: true
  attr :sort_by, :string, default: "relevance"
  attr :search_state, :map

  def search_item(assigns) do
    ~H"""
    <div
      id={"item-#{@item.id}"}
      class="item"
      phx-hook="ShowPageCount"
      data-id={@item.id}
      data-filecount={@item.file_count}
    >
      <.link navigate={@item.url} class="thumb-link">
        <div class="flex flex-wrap gap-5 md:max-h-60 max-h-[22rem] overflow-hidden justify-center md:justify-start relative">
          <.thumbs
            :for={{thumb, thumb_num} <- thumbnail_service_urls(5, @item)}
            :if={@item.file_count}
            thumb={thumb}
            thumb_num={thumb_num}
            link={@item.url}
          />
          <div id={"filecount-#{@item.id}"} class="hidden absolute right-0 top-0 bg-white px-4 py-2">
            {@item.file_count} {gettext("Images")}
          </div>
        </div>
      </.link>
      <div data-field="genre" class="pt-4 text-gray-600 font-bold text-sm uppercase">
        <.link navigate={self_route(@search_state, %{filter: %{"genre" => List.first(@item.genre)}})}>
          {@item.genre}
        </.link>
      </div>
      <h2 dir="auto">
        <.link navigate={@item.url}>{@item.title}</.link>
      </h2>
      <div class="flex items-start">
        <div class="text-xl">{@item.date}</div>
        <div
          :if={@sort_by == :recently_updated && @item.updated_at}
          class="updated-at self-end w-full pb-2 text-right"
        >
          {gettext("Added")} {DpulCollectionsWeb.BrowseItem.time_ago(@item.updated_at)}
        </div>
      </div>
    </div>
    """
  end

  def results_for_keywords_heading(assigns) do
    ~H"""
    <h1 class="flex">
      {gettext("Search Results for")}:&nbsp;
      <span dir="auto" class="normal-case flex-grow">
        <%= if @keywords do %>
          {@keywords}
        <% else %>
          [ {gettext("All Possible Items")} ]
        <% end %>
      </span>
    </h1>
    """
  end

  def thumbs(assigns) do
    ~H"""
    <img
      class="h-[350px] w-[350px] md:h-[225px] md:w-[225px] border border-solid border-gray-400"
      src={"#{@thumb}/square/350,350/0/default.jpg"}
      alt={"image #{@thumb_num}"}
      style="
          background-color: lightgray;"
      width="350"
      height="350"
    />
    """
  end

  def paginator(assigns) do
    ~H"""
    <nav aria-label="Search Results Page Navigation" class="paginator inline-flex -space-x-px text-sm">
      <.link
        :if={@page > 1}
        id="paginator-previous"
        class="flex items-center justify-center px-3 h-8 leading-tight border border-dark-blue bg-primary text-sage hover:text-white"
        phx-click="paginate"
        phx-value-page={@page - 1}
      >
        <span class="sr-only">{gettext("Previous")}</span>
        <svg
          class="w-2.5 h-2.5 rtl:rotate-180"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 6 10"
        >
          <path
            stroke="currentColor"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M5 1 1 5l4 4"
          />
        </svg>
      </.link>
      <.page_link_or_span
        :for={{text, current_page?} <- pages(@page, @per_page, @total_items)}
        text={text}
        class={"
          flex
          items-center
          justify-center
          px-3
          h-8
          leading-tight
          #{if current_page?, do: "active", else: "
              border-dark-blue
              text-dark-text
              bg-white border
              hover:bg-gray-100
              hover:text-gray-700
              no-underline
            "}
        "}
      />
      <.link
        :if={more_pages?(@page, @per_page, @total_items)}
        id="paginator-next"
        class="flex items-center justify-center px-3 h-8 leading-tight border border-dark-blue bg-primary text-sage hover:text-white"
        phx-click="paginate"
        phx-value-page={@page + 1}
      >
        <span class="sr-only">{gettext("Next")}</span>
        <svg
          class="w-2.5 h-2.5 rtl:rotate-180"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 6 10"
        >
          <path
            stroke="currentColor"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="m1 9 4-4-4-4"
          />
        </svg>
      </.link>
    </nav>
    """
  end

  def handle_event("filter-date", params, socket) do
    params =
      %{
        socket.assigns.search_state
        | filter: Map.merge(socket.assigns.search_state.filter, params["filter"])
      }
      |> Helpers.clean_params([:page, :per_page])

    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("sort", params, socket) do
    params =
      %{socket.assigns.search_state | sort_by: params["sort-by"]}
      |> Helpers.clean_params([:page, :per_page])

    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    params = %{socket.assigns.search_state | page: page} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def self_route(search_state, extra \\ %{}) do
    params = Map.merge(search_state, extra, &merger/3) |> Helpers.clean_params()
    ~p"/search?#{params}"
  end

  # Merge new filters with existing filters.
  def merger(:filter, first_filter = %{}, second_filter = %{}),
    do: Map.merge(first_filter, second_filter)

  defp more_pages?(page, per_page, total_items) do
    page * per_page < total_items
  end

  defp pages(page, per_page, total_items) do
    page_count = ceil(total_items / per_page)
    page_range = (page - 2)..(page + 2)

    pages =
      for page_number <- page_range,
          page_number > 0 do
        if page_number <= page_count do
          current_page? = page_number == page
          {page_number, current_page?}
        end
      end

    # Add the prefix (1...) and postfix (...last_page)
    # tail element to the paginator.
    paginator_tail(:pre, 1, page_range) ++
      pages ++
      paginator_tail(:post, page_count, page_range)
  end

  defp paginator_tail(type, page, page_range) do
    cond do
      Enum.member?(page_range |> Enum.to_list(), page) -> []
      type == :pre -> [{page, false}, {"...", false}]
      type == :post -> [{"...", false}, {page, false}]
    end
  end

  defp thumbnail_service_urls(max_thumbnails, item) do
    thumbnail_service_urls(
      max_thumbnails,
      item.image_service_urls,
      item.primary_thumbnail_service_url
    )
  end

  defp thumbnail_service_urls(max_thumbnails, image_service_urls, nil) do
    # Truncate image service urls to max value
    image_service_urls
    |> Enum.slice(0, max_thumbnails)
    |> Enum.with_index()
  end

  defp thumbnail_service_urls(max_thumbnails, image_service_urls, primary_thumbnail_service_url) do
    # Move thumbnail url to front of list and then truncate to max value
    image_service_urls
    |> Enum.filter(&(&1 != primary_thumbnail_service_url))
    |> List.insert_at(0, primary_thumbnail_service_url)
    |> Enum.slice(0, max_thumbnails)
    |> Enum.with_index()
  end
end

defmodule DpulCollectionsWeb.SearchLive do
  alias DpulCollections.Collection
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}
  use Solr.Constants
  alias DpulCollectionsWeb.Live.Helpers
  alias DpulCollectionsWeb.SearchLive.SearchState
  alias DpulCollectionsWeb.ContentWarnings

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    search_state = SearchState.from_params(params |> Helpers.clean_params())

    %{
      results: items,
      total_items: total_items,
      filter_data: filter_data
    } = Solr.search(search_state)

    socket =
      socket
      |> assign(
        page_title: "Search Results - Digital Collections",
        search_state: search_state,
        item_counter: item_counter(search_state, total_items),
        items: items,
        total_items: total_items,
        filter_data: filter_data,
        filter_form: to_form(params["filter"] || %{}, as: "filter")
      )
      |> assign_new(
        :expanded_filter,
        fn -> nil end
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

  def filter_button(assigns) do
    ~H"""
    <div class={[
      "group w-full h-full text-xl font-semibold not-last:border-r-1 border-rust/20",
      "#{@expanded && "expanded"}"
    ]}>
      <button
        phx-click="select_filter"
        type="button"
        role="tab"
        phx-value-filter={@field}
        class="group-[.expanded]:bg-accent group-[.expanded]:text-light-text p-4 hover:text-dark-text hover:bg-hover-accent cursor-pointer w-full h-full flex items-center text-left"
      >
        <span class="grow">
          {@label}
        </span>
        <div class="arrow bg-dark-text group-[.expanded]:bg-light-text group-[.expanded:hover]:bg-dark-text rotate-90 group-[.expanded]:-rotate-90 w-[15px] h-[15px]">
        </div>
      </button>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="content-area page-b-padding">
        <.results_for_keywords_heading keywords={@search_state.q} />
      </div>
      <section class="w-full">
        <.form
          id="filter-form"
          phx-change="checked_filter"
          for={@filter_form}
        >
          <div class="content-area">
            <h2 class="text-xl font-normal page-b-padding">Filter your results</h2>
            <div
              role="tablist"
              class={[
                "border-t-1 border-rust/20 w-full grid grid-flow-col auto-cols-auto",
                !@expanded_filter && "border-b-1"
              ]}
            >
              <.filter_button
                :for={{field, filter} <- @filter_data}
                label={filter.label}
                field={field}
                expanded={field == @expanded_filter}
              />
            </div>
          </div>
          <div
            :for={{field, filter} <- @filter_data}
            role="tabpanel"
            class={[
              @expanded_filter == field || "hidden",
              @expanded_filter == field && "expanded",
              "bg-secondary page-y-padding border-t-4 border-b-4 border-accent w-full"
            ]}
          >
            <div class="content-area flex flex-col gap-6">
              <div class="flex items-center w-full gap-2" role="search">
                <input
                  class="border-2 border-dark-text/20 grow h-full placeholder:text-dark-text/40 bg-light-text border-none placeholder:text-xl text-xl placeholder:font-bold w-full"
                  type="text"
                  placeholder={"#{gettext("Filter by")} #{filter.label}"}
                  dir="auto"
                />
              </div>
              <div class="flex">
                <div class="w-full grow">
                  <.input
                    type="checkgroup"
                    field={@filter_form[field]}
                    multiple={true}
                    class="w-full grid gap-6 grid-cols-[repeat(auto-fit,minmax(20rem,1fr))]"
                    options={
                      filter.data |> Enum.map(fn {value, count} -> {"#{value} [#{count}]", value} end)
                    }
                  />
                </div>
              </div>
            </div>
          </div>
        </.form>
      </section>
      <section class="content-area">
        <div class="page-y-padding grid grid-flow-row auto-rows-max gap-6">
          <div id="filters" class="flex flex-wrap gap-4">
            <form
              id="date-filter"
              phx-submit="filter-date"
              class="flex flex-wrap gap-2"
            >
              <label class="self-center font-bold uppercase" for="date-filter">
                {gettext("filter by year")}:
              </label>
              <label class="sr-only" for="filter[year][from]">{gettext("From")}</label>
              <input
                type="text"
                placeholder={gettext("From")}
                form="date-filter"
                name="filter[year][from]"
                id="filter[year][from]"
                value={@search_state.filter["year"]["from"]}
              />
              <label class="sr-only" for="filter[year][to]">{gettext("To")}</label>
              <input
                type="text"
                placeholder={gettext("To")}
                form="date-filter"
                name="filter[year][to]"
                id="filter[year][to]"
                value={@search_state.filter["year"]["to"]}
              />
              <.primary_button type="submit">
                {gettext("Apply")}
              </.primary_button>
            </form>
            <form id="sort-form" class="grid md:grid-cols-[auto_200px] gap-2" phx-change="sort">
              <label class="col-span-1 self-center font-bold uppercase md:text-right" for="sort-by">
                {gettext("sort by")}:
              </label>
              <select id="sort-by" class="col-span-1" name="sort-by" aria-label={gettext("sort by")}>
                {Phoenix.HTML.Form.options_for_select(
                  sort_by_params(),
                  @search_state.sort_by
                )}
              </select>
            </form>
            <form id="filter-pills" class="md:col-span-2">
              <div class="select-none flex flex-wrap gap-4">
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
        <ul class="grid grid-flow-row auto-rows-max gap-8">
          <li :for={item <- @items}>
            <.search_item
              search_state={@search_state}
              item={item}
              sort_by={@search_state.sort_by}
              show_images={@show_images}
            />
          </li>
        </ul>
        <div class="text-center max-w-5xl mx-auto text-lg py-8">
          <.paginator
            page={@search_state.page}
            per_page={@search_state.per_page}
            total_items={@total_items}
          />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :field, :string, required: true
  attr :filter_value, :string, required: true
  attr :label, :string, required: true
  attr :search_state, :map, required: true

  def filter(assigns = %{filter_value: filter_values}) when is_list(filter_values) do
    ~H"""
    <.filter
      :for={filter_value <- @filter_value}
      filter_value={filter_value}
      field={@field}
      search_state={@search_state}
      label={@label}
    />
    """
  end

  def filter(assigns = %{filter_value: filter_value}) when is_binary(filter_value) do
    ~H"""
    <.link
      :if={@filter_value}
      role="button"
      phx-value-filter-value={@filter_value}
      phx-value-filter={@field}
      phx-click="remove_filter"
      class="filter focus:border-3 focus:visible:border-accent focus:border-accent py-1 px-4 shadow-md no-underline rounded-lg bg-primary border-dark-blue font-sans font-bold text-sm btn-primary hover:text-white hover:bg-accent focus:outline-none active:shadow-none"
    >
      {# These labels are defined explicitly in Solr.Constants, but have to be called here because Constants is defined at compile time.}
      {Gettext.gettext(DpulCollectionsWeb.Gettext, @label)}
      <span><.icon name="hero-chevron-right" class="p-1 h-4 w-4 icon" /></span>
      <span class="filter-text">
        {@filter_value}
      </span>
      <span><.icon name="hero-x-circle" class="ml-2 h-6 w-6 icon" /></span>
    </.link>
    """
  end

  def filter(assigns) do
    ~H"""
    """
  end

  def search_item(assigns = %{item: %Collection{}}) do
    ~H"""
    <div
      id={"item-#{@item.id}"}
      class="item card"
      data-id={@item.id}
    >
      <div class="grid-rows-2 bg-sage-100 grid sm:grid-rows-1 sm:grid-cols-4 gap-0">
        <div class={[
          "search-thumbnail",
          "row-span-2 col-span-1",
          "bg-search flex justify-center relative",
          "h-[350px]"
        ]}>
          <div class="grid grid-cols-2 w-full gap-2 h-[350px] p-2">
            <img
              :for={item <- @item.featured_items}
              src={"#{item.primary_thumbnail_service_url}/full/!#{item.primary_thumbnail_width},#{item.primary_thumbnail_height}/0/default.jpg"}
              width={item.primary_thumbnail_width}
              height={item.primary_thumbnail_height}
              class="min-h-0 min-w-0 object-cover object-top h-full w-full max-h-full"
              alt={item.title |> hd}
            />
          </div>
        </div>
        <div
          class="metadata sm:col-span-3 flex flex-col gap-2 sm:gap-4 p-4"
          id={"item-metadata-#{@item.id}"}
        >
          <div class="flex flex-wrap flex-row sm:flex-row justify-between">
            <.link
              navigate={@item.url}
              class="before:content-[''] before:absolute before:inset-0 before:z-[1]"
            >
              <h2 dir="auto w-full flex-grow sm:w-fit">
                {@item.title}
              </h2>
            </.link>
            <span
              data-field="genre"
              class="w-full sm:w-fit flex-grow sm:flex-none text-gray-600 font-bold text-base uppercase sm:text-right"
            >
              {@item.genre}
            </span>
          </div>
          <div :if={@item.tagline} class="text-base">{@item.tagline}</div>
          <div class="brief-metadata flex flex-auto flex-row gap-4">
            <div class="flex flex-col pe-4 gap-0 py-0 h-min">
              <div class="text-lg">{@item.item_count}</div>
              <div class="text-base">Items</div>
            </div>
            <div class="flex flex-col pe-4 gap-0 py-0 h-min">
              <div class="text-lg">{length(@item.languages)}</div>
              <div class="text-base">Languages</div>
            </div>
            <div class="flex flex-col pe-4 gap-0 py-0 h-min">
              <div class="text-lg">{length(@item.geographic_origins)}</div>
              <div class="text-base">Locations</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def search_item(assigns = %{item: %Item{}}) do
    ~H"""
    <div
      id={"item-#{@item.id}"}
      class="item card"
      aria-label={@item.title |> hd}
      phx-hook="ShowPageCount"
      data-id={@item.id}
      data-filecount={@item.file_count}
    >
      <div
        :if={Helpers.obfuscate_item?(assigns)}
        class="h-[2.5rem]"
      >
        <ContentWarnings.show_images_banner
          item_id={@item.id}
          content_warning={@item.content_warning}
        />
      </div>
      <div class="grid-rows-2 bg-sage-100 grid sm:grid-rows-1 sm:grid-cols-4 gap-0">
        <.large_thumb
          :if={@item.file_count && length(@item.image_service_urls) > 0}
          thumb={elem(hd(thumbnail_service_urls(0, 1, @item)), 0)}
          thumb_num={0}
          item={@item}
          show_images={@show_images}
        />
        <div
          class="metadata sm:col-span-3 sm:col-start-2 flex flex-col gap-2 sm:gap-4 p-4"
          id={"item-metadata-#{@item.id}"}
        >
          <div class="flex flex-wrap flex-row sm:flex-row justify-between">
            <.link
              navigate={@item.url}
              class="before:content-[''] before:absolute before:inset-0 before:z-[1]"
            >
              <h2 dir="auto w-full flex-grow sm:w-fit">
                {@item.title}
              </h2>
            </.link>
            <span
              data-field="genre"
              class="w-full sm:w-fit flex-grow sm:flex-none text-gray-600 font-bold text-base uppercase sm:text-right"
            >
              {@item.genre}
            </span>
          </div>
          <div :if={@sort_by == :recently_updated && @item.updated_at} class="updated-at w-full">
            {gettext("Added")} {DpulCollectionsWeb.BrowseItem.time_ago(@item.updated_at)}
          </div>
          <.search_brief_metadata item={@item} />
          <div class="small-thumbnails hidden sm:flex flex-row flex-wrap gap-5 max-h-[125px] justify-start overflow-hidden">
            <.thumbs
              :for={{thumb, thumb_num} <- thumbnail_service_urls(1, 6, @item)}
              :if={@item.file_count > 1}
              thumb={thumb}
              thumb_num={thumb_num + 1}
              item={@item}
              show_images={@show_images}
            />
            <div
              id={"filecount-#{@item.id}"}
              class="hidden absolute diagonal-rise -right-px bottom-0 bg-sage-100 pr-4 py-2 text-sm"
            >
              {@item.file_count} {gettext("Images")}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp search_brief_metadata(assigns) do
    ~H"""
    <div class="brief-metadata flex-auto flex flex-row gap-4">
      <div
        :if={@item.date}
        class="date flex flex-col gap-0 pe-4 py-0 h-min"
      >
        <div class="text-base">Date</div>
        <div class="text-lg">{@item.date}</div>
      </div>
      <div
        :if={@item.geographic_origin}
        class="origin flex flex-col gap-0 pe-4 py-0 h-min"
      >
        <div class="text-base">Origin</div>
        <div class="text-lg">{@item.geographic_origin}</div>
      </div>
    </div>
    """
  end

  def results_for_keywords_heading(assigns) do
    ~H"""
    <h1 class="flex flex-wrap">
      <div>
        {gettext("Search Results for")}:&nbsp;
      </div>
      <div dir="auto" class="normal-case flex-grow">
        <%= if @keywords do %>
          {@keywords}
        <% else %>
          [ {gettext("All Possible Items")} ]
        <% end %>
      </div>
    </h1>
    """
  end

  def large_thumb(assigns) do
    ~H"""
    <div class={[
      "search-thumbnail",
      "row-span-2 col-span-1",
      "bg-search flex justify-center relative"
    ]}>
      <img
        class={[
          "h-[350px] w-[350px]",
          "sm:h-[225px] md:w-[225px]",
          "bg-search object-contain p-2",
          Helpers.obfuscate_item?(assigns) && "obfuscate",
          "thumbnail-#{@item.id}",
          "place-self-center"
        ]}
        src={"#{@thumb}/full/!350,350/0/default.jpg"}
        alt={"image #{@thumb_num}"}
      />
      <div
        :if={@item.file_count > 1}
        class="absolute sm:hidden diagonal-rise right-0 bottom-0 bg-sage-100 pr-4 py-2"
      >
        {@item.file_count} {gettext("Images")}
      </div>
    </div>
    """
  end

  def thumbs(assigns) do
    ~H"""
    <div class="relative">
      <img
        class={[
          "h-[125px] w-[125px] md:h-[125px] md:w-[125px] border border-solid border-gray-400",
          Helpers.obfuscate_item?(assigns) && "obfuscate",
          "thumbnail-#{@item.id}"
        ]}
        src={"#{@thumb}/square/350,350/0/default.jpg"}
        alt={"image #{@thumb_num}"}
        style="background-color: lightgray;"
        width="125"
        height="125"
      />
    </div>
    """
  end

  def paginator(assigns) do
    ~H"""
    <nav
      aria-label={gettext("Search Results Page Navigation")}
      class="paginator inline-flex -space-x-px text-sm"
    >
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
        current_page={current_page?}
        class="flex items-center justify-center px-3 h-8 leading-tight border border-dark-blue"
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

  attr :text, :string, doc: "the page number, or ellipsis"
  attr :current_page, :boolean, default: false, doc: "whether this is the current page"
  attr :class, :string

  def page_link_or_span(assigns = %{current_page: false, text: "..."}) do
    ~H"""
    <span class={[@class, "text-dark-text bg-white"]}>
      {@text}
    </span>
    """
  end

  def page_link_or_span(assigns = %{current_page: false}) do
    ~H"""
    <a
      class={[@class, "no-underline hover:bg-gray-100 hover:text-gray-700 text-dark-text bg-white"]}
      href="#"
      phx-click="paginate"
      phx-value-page={@text}
    >
      {@text}
    </a>
    """
  end

  def page_link_or_span(assigns = %{current_page: true}) do
    ~H"""
    <span class={[@class, "active bg-accent font-semibold"]}>
      {@text}
    </span>
    """
  end

  def handle_event(
        "remove_filter",
        %{"filter" => filter, "filter-value" => value},
        socket = %{assigns: %{search_state: search_state}}
      ) do
    new_state =
      search_state
      |> SearchState.remove_filter_value(filter, value)

    {:noreply, push_patch(socket, to: ~p"/search?#{new_state}")}
  end

  def handle_event(
        "checked_filter",
        %{"filter" => selected_filters},
        socket = %{assigns: %{search_state: search_state}}
      ) do
    new_state =
      selected_filters
      |> Enum.reduce(search_state, fn {filter, values}, acc_state ->
        SearchState.set_filter(acc_state, filter, values)
      end)

    socket = push_patch(socket, to: ~p"/search?#{new_state}")
    {:noreply, socket}
  end

  # When we click an expanded one, disable it.
  def handle_event(
        "select_filter",
        %{"filter" => field},
        socket = %{assigns: %{expanded_filter: field}}
      ) do
    {:noreply, socket |> assign(:expanded_filter, nil)}
  end

  # When we click a filter that's not selected, disable it.
  def handle_event("select_filter", %{"filter" => field}, socket) do
    {:noreply, socket |> assign(:expanded_filter, field)}
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

  defp thumbnail_service_urls(start, max_thumbnails, item) do
    thumbnail_service_urls(
      start,
      max_thumbnails,
      item.image_service_urls,
      item.primary_thumbnail_service_url
    )
  end

  defp thumbnail_service_urls(start, max_thumbnails, image_service_urls, nil) do
    # Truncate image service urls to max value
    image_service_urls
    |> Enum.slice(start, max_thumbnails)
    |> Enum.with_index()
  end

  defp thumbnail_service_urls(
         start,
         max_thumbnails,
         image_service_urls,
         primary_thumbnail_service_url
       ) do
    # Move thumbnail url to front of list and then truncate to max value
    image_service_urls
    |> Enum.filter(&(&1 != primary_thumbnail_service_url))
    |> List.insert_at(0, primary_thumbnail_service_url)
    |> Enum.slice(start, max_thumbnails)
    |> Enum.with_index()
  end
end

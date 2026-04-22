defmodule DpulCollectionsWeb.SearchLive do
  alias DpulCollections.Collection
  alias DpulCollectionsWeb.UserSets
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}
  use Solr.Constants
  alias DpulCollectionsWeb.Live.Helpers
  alias DpulCollectionsWeb.SearchLive.SearchState
  alias DpulCollectionsWeb.SearchLive.SearchItem
  alias DpulCollectionsWeb.ContentWarnings

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket = assign_search_state(socket, params)
    search_state = socket.assigns.search_state

    %{
      results: items,
      total_items: total_items,
      filter_data: filter_data
    } = Solr.search(search_state)

    {:noreply,
     socket
     |> assign(
       page_title: "Search Results - Digital Collections",
       item_counter: item_counter(search_state, total_items),
       items: items,
       total_items: total_items,
       filter_data: with_year_filter(filter_data)
     )
     |> assign_new(
       :expanded_filter,
       fn -> nil end
     )}
  end

  defp assign_search_state(socket, params) do
    search_state = SearchState.from_params(params |> Helpers.clean_params())

    socket
    |> assign(
      search_state: search_state,
      filter_form: to_form(params["filter"] || %{}, as: "filter"),
      year_form:
        to_form(
          get_in(params, [Access.key("filter", %{}), Access.key("year", %{})]),
          as: "filter[year]"
        )
    )
  end

  defp with_year_filter(filter_data) do
    filter_data
    |> Map.put("year", %{label: @filters["year"].label, data: [true]})
    |> order_filters()
  end

  defp order_filters(filter_data) do
    filter_data
    |> Enum.sort_by(fn {label, _} ->
      Enum.find_index(@filter_fields, fn filter_field -> label == filter_field end)
    end)
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

  attr :current_scope, :map, required: false, default: nil

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} search_state={@search_state}>
      <div class="content-area page-b-padding">
        <.results_for_keywords_heading keywords={@search_state.q} />
      </div>
      <.filters
        search_state={@search_state}
        total_items={@total_items}
        filter_form={@filter_form}
        year_form={@year_form}
        filter_data={@filter_data}
        expanded_filter={@expanded_filter}
      />
      <section class="content-area">
        <div class="py-4 flex flex-row justify-between gap-4">
          <div id="item-counter" class="place-content-center">
            {@item_counter}
          </div>
          <div class="flex flex-wrap gap-4">
            <form
              :if={@total_items > 0}
              id="sort-form"
              class="grid md:grid-cols-[auto_200px] gap-2"
              phx-change="sort"
            >
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
          </div>
        </div>
        <ul class="grid grid-flow-row auto-rows-max gap-8" id="search-results">
          <.live_component
            :for={item <- @items}
            id={"search-item-#{item.id}"}
            module={SearchItem}
            search_state={@search_state}
            item={item}
            sort_by={@search_state.sort_by}
            show_images={@show_images}
            current_scope={@current_scope}
            current_path={@current_path}
          />
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

  def filters(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".SearchFilter">
      export default {
        mounted() {
          this.input = this.el.querySelector('input[type="search"]');
          this.options = this.el.querySelector('[phx-feedback-for]');
          if (!this.input || !this.options) return;

          this.input.addEventListener('input', e => {
            this.search(e.target.value)
          });
        },

        updated() {
          this.search(this.input.value)
        },

        async search(query) {
          const items = Array.from(this.options.querySelectorAll('label')).map(el => ({
            el,
            value: el.querySelector('input[type="checkbox"]')?.value || el.querySelector('span')?.textContent?.trim() || ''
          }));

          if (!query?.trim()) {
            items.forEach(i => { i.el.classList.remove('hidden') });
            return;
          }

          const q = query.toLowerCase();
          items.forEach(i => {
            i.el.classList.toggle('hidden', !i.value.toLowerCase().includes(q));
          });
        }
      }
    </script>
    <section id="filters">
      <div id="search-filters" class="content-area py-4 w-full">
        <div class="flex items-center gap-4 flex-wrap">
          <.primary_button
            type="button"
            phx-click={JS.exec("dcjs-open", to: "#filter-modal")}
            class="flex h-full items-center gap-2 px-4 py-2 cursor-pointer"
          >
            <.icon name="hero-funnel" class="h-5 w-5" />
            {gettext("Filters")}
          </.primary_button>

          <div
            :if={map_size(@search_state.filter) > 0}
            class="flex flex-wrap gap-2 items-center w-full"
          >
            <.filter_pill
              :for={{filter_field, filter_settings} <- filter_configuration()}
              search_state={@search_state}
              field={filter_field}
              label={filter_settings.label}
              filter_value={filter_settings.value_function.(@search_state.filter[filter_field])}
            />
          </div>
        </div>
      </div>

      <.drawer id="filter-modal" label={gettext("Filter Results")}>
        <div class={[
          "px-4 py-3 bg-primary-light border-b border-rust/20",
          map_size(@search_state.filter) == 0 && "hidden"
        ]}>
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-semibold">{gettext("Active Filters")}</span>
            <.link
              patch="/search"
              class="text-xs text-accent hover:underline"
            >
              {gettext("Clear all")}
            </.link>
          </div>
          <div class="flex flex-wrap gap-2">
            <.filter_pill
              :for={{filter_field, filter_settings} <- filter_configuration()}
              search_state={@search_state}
              field={filter_field}
              label={filter_settings.label}
              filter_value={filter_settings.value_function.(@search_state.filter[filter_field])}
            />
          </div>
        </div>

        <.filter_form_component
          search_state={@search_state}
          total_items={@total_items}
          filter_form={@filter_form}
          year_form={@year_form}
          filter_data={@filter_data}
          expanded_filter={@expanded_filter}
        />
      </.drawer>
    </section>
    """
  end

  def hidden_filters() do
    @filter_keys -- @filter_fields
  end

  def filter_form_component(assigns) do
    ~H"""
    <.form
      :if={@total_items > 0}
      id="filter-form"
      phx-change="checked_filter"
      phx-submit="apply_filters"
      for={@filter_form}
      class="grow flex flex-col"
    >
      <div class="p-4 flex flex-col gap-4 grow">
        <p class="text-sm text-dark-text">
          Filter your {@total_items} results
        </p>

        <div class="flex flex-col gap-4">
          <.filter_section
            :for={{field, filter} <- @filter_data}
            field={field}
            filter={filter}
            expanded={field == @expanded_filter}
            filter_form={@filter_form}
            year_form={@year_form}
          />

          <.input
            :for={hidden_filter <- hidden_filters()}
            type="hidden"
            field={@filter_form[hidden_filter]}
          />
          <input
            name="q"
            type="hidden"
            value={@search_state[:q]}
          />
        </div>
      </div>

      <%!-- Footer with view results button --%>
      <div class="sticky bottom-0 px-4 py-4 bg-sage-100 border-t border-rust/20">
        <.primary_button
          phx-click={JS.exec("dcjs-close", to: "#filter-modal")}
          class="cursor-pointer w-full py-3 font-bold rounded-md"
        >
          {gettext("View")} {@total_items} {gettext("Results")}
        </.primary_button>
      </div>
    </.form>
    """
  end

  defp filter_section(assigns) do
    ~H"""
    <div class={[
      "border border-rust/20 rounded-lg overflow-hidden bg-white",
      length(@filter.data) == 0 && "hidden"
    ]}>
      <button
        id={"#{@field}-panel-button"}
        type="button"
        phx-click="select_filter_tab"
        phx-value-filter={@field}
        aria-controls={"#{@field}-panel"}
        aria-expanded={to_string(@expanded)}
        class={[
          "cursor-pointer w-full flex items-center justify-between px-4 py-3 text-left font-semibold",
          "hover:bg-primary-bright transition-colors",
          @expanded && "bg-primary-bright"
        ]}
      >
        <span>{Gettext.gettext(DpulCollectionsWeb.Gettext, @filter.label)}</span>
        <.icon
          name="hero-chevron-down"
          class={
            if @expanded,
              do: "h-5 w-5 transition-transform duration-200 rotate-180",
              else: "h-5 w-5 transition-transform duration-200"
          }
        />
      </button>

      <div
        id={"#{@field}-panel"}
        class={["px-4 pb-4 border-t border-rust/10", @expanded && "expanded", !@expanded && "hidden"]}
      >
        <.filter_input
          field={@field}
          filter={@filter}
          filter_form={@filter_form}
          year_form={@year_form}
          filter_configuration={filter_configuration()[@field]}
        />
      </div>
    </div>
    """
  end

  def filter_pill(assigns = %{filter_value: filter_values}) when is_list(filter_values) do
    ~H"""
    <.filter_pill
      :for={filter_value <- @filter_value}
      filter_value={filter_value}
      field={@field}
      search_state={@search_state}
      label={@label}
    />
    """
  end

  def filter_pill(assigns = %{filter_value: filter_value}) when is_binary(filter_value) do
    ~H"""
    <.primary_button
      :if={@filter_value}
      role="button"
      phx-value-filter-value={@filter_value}
      phx-value-filter={@field}
      phx-click="remove_filter"
      class={[
        @field,
        "filter flex max-w-full gap-1 py-2 px-4 btn-primary no-underline font-semibold *:font-semibold text-sm h-full"
      ]}
    >
      {# These labels are defined explicitly in Solr.Constants, but have to be called here because Constants is defined at compile time.}
      {Gettext.gettext(DpulCollectionsWeb.Gettext, @label)}
      <span><.icon name="hero-chevron-right" class="p-1 h-4 w-4 icon" /></span>
      <span class="filter-text truncate">
        {@filter_value}
      </span>
      <span><.icon name="hero-x-circle" class="ml-2 h-6 w-6 icon" /></span>
    </.primary_button>
    """
  end

  def filter_pill(assigns) do
    ~H"""
    """
  end

  def filter_input(assigns = %{field: "year"}) do
    ~H"""
    <div class="pt-3 space-y-3">
      <div class="grid grid-cols-2 gap-3">
        <.input
          placeholder={gettext("From")}
          label={gettext("From")}
          field={@year_form["from"]}
        />
        <.input
          placeholder={gettext("To")}
          label={gettext("To")}
          field={@year_form["to"]}
        />
      </div>
      <.primary_button type="submit" class="w-full h-10 text-sm">
        {gettext("Apply Year Range")}
      </.primary_button>
    </div>
    """
  end

  def filter_input(assigns) do
    ~H"""
    <div id={"search-#{@field}"} phx-hook=".SearchFilter" class="pt-3">
      <div class="relative mb-2" phx-update="ignore" id={"search-wrapper-#{@field}"}>
        <label for={"filter-#{@field}-search"} class="sr-only">
          {gettext("Search")} {Gettext.gettext(DpulCollectionsWeb.Gettext, @filter.label)} {gettext(
            "filters"
          )}
        </label>
        <input
          type="search"
          placeholder={gettext("Search filters...")}
          class="w-full px-3 py-2 text-sm border border-rust/20 rounded-md focus:ring-accent focus:border-accent"
          autocomplete="off"
          id={"filter-#{@field}-search"}
          dir="auto"
        />
      </div>
      <.input
        data-filter-options
        type="checkgroup"
        field={@filter_form[@field]}
        multiple={true}
        class="max-h-100 overflow-y-auto grid grid-cols-1 sm:grid-cols-1 space-y-1"
        options={
          @filter.data
          |> Enum.map(fn {value, count} -> {{value, count}, value} end)
        }
      />
    </div>
    """
  end

  def filter_configuration do
    @filters
  end

  def sort_by_params do
    @valid_sort_by
    # Don't include things without labels.
    |> Enum.filter(fn {_, v} -> v[:label] end)
    |> Enum.map(fn {k, v} -> {v[:label], k} end)
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

  def results_for_keywords_heading(assigns) do
    ~H"""
    <h1 class="flex flex-wrap">
      <%= if @keywords do %>
        {gettext("Search Results")}:&nbsp;
        <span dir="auto" class="normal-case flex-grow">
          {@keywords}
        </span>
      <% else %>
        <div>
          {gettext("Search Results")}
        </div>
      <% end %>
    </h1>
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
      |> SearchState.reset_pagination()

    {:noreply, push_patch(socket, to: ~p"/search?#{new_state}")}
  end

  def handle_event("apply_filters", params, socket) do
    params =
      params |> Map.merge(%{"page" => "1"}) |> SearchState.from_params() |> Helpers.clean_params()

    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  # Don't do ranges with changed events.
  def handle_event("checked_filter", %{"_target" => ["filter", _filter, _from_or_to]}, socket),
    do: {:noreply, socket}

  # Don't process the search boxes.
  def handle_event("checked_filter", %{"_target" => ["undefined"]}, socket),
    do: {:noreply, socket}

  def handle_event(
        "checked_filter",
        params = %{"_target" => ["filter", filter]},
        socket = %{assigns: %{search_state: search_state}}
      ) do
    new_state =
      search_state
      |> SearchState.set_filter(filter, get_in(params, ["filter", filter]))
      |> SearchState.reset_pagination()

    socket = push_patch(socket, to: ~p"/search?#{new_state}")
    {:noreply, socket}
  end

  # When we click an expanded one, disable it.
  def handle_event(
        "select_filter_tab",
        %{"filter" => field},
        socket = %{assigns: %{expanded_filter: field}}
      ) do
    {:noreply, socket |> assign(:expanded_filter, nil)}
  end

  # When we click a filter that's not selected, activate it.
  def handle_event("select_filter_tab", %{"filter" => field}, socket) do
    socket = socket |> assign(:expanded_filter, field)
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
end

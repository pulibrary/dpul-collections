defmodule DpulCollectionsWeb.Search.ScrollFilter do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def mount(socket), do: {:ok, assign(socket, query: "", page: 1, limit: 100)}

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_options()}
  end

  def handle_event("search", %{"filter_query" => query}, socket) do
    {:noreply, socket |> assign(query: query, page: 1) |> assign_options()}
  end

  def handle_event("next_page", _, socket = %{assigns: %{page: page, max_page: max_page}})
      when max_page > page do
    {:noreply, socket |> assign(page: page + 1) |> assign_options()}
  end

  defp assign_options(
         %{
           assigns: %{
             query: query,
             filter: filter,
             filter_form: form,
             field: field,
             page: page,
             limit: limit
           }
         } = socket
       ) do
    q = query |> String.trim() |> String.downcase()

    filtered =
      if q == "",
        do: filter.data,
        else: Enum.filter(filter.data, fn {v, _} -> String.contains?(String.downcase(v), q) end)

    visible =
      filtered
      |> Enum.take(page * limit)

    visible_values = MapSet.new(visible, fn {v, _} -> String.downcase(v) end)

    hidden_selected =
      List.wrap(form[field].value)
      |> Enum.reject(&(String.downcase(&1) in visible_values))

    filter_length = length(filtered)
    # Get the highest possible page - div does integer math
    max_page = div(filter_length + limit - 1, limit)

    assign(socket, options: visible, hidden_selected: hidden_selected, max_page: max_page)
  end

  attr :field, :string
  attr :filter_form, :map
  attr :filter, :map

  def render(assigns) do
    ~H"""
    <div id={"search-#{@field}"} class="pt-3">
      <div class="relative mb-2">
        <label for={"filter-#{@field}-search"} class="sr-only">
          {gettext("Search")} {Gettext.gettext(DpulCollectionsWeb.Gettext, @filter.label)} {gettext(
            "filters"
          )}
        </label>
        <input
          id={"filter-#{@field}-search"}
          type="search"
          name="filter_query"
          value={@query}
          phx-change={
            JS.push("search", target: @myself)
            |> JS.dispatch("dpulc:resetScroll", to: "#filter-#{@field}-scroll")
          }
          phx-debounce="200"
          placeholder={gettext("Search filters...")}
          class="w-full px-3 py-2 text-sm border border-rust/20 rounded-md focus:ring-accent focus:border-accent"
          autocomplete="off"
          dir="auto"
        />
      </div>
      <input
        :for={value <- @hidden_selected}
        type="hidden"
        name={@filter_form[@field].name <> "[]"}
        value={value}
      />
      <.input
        data-filter-options
        type="checkgroup"
        field={@filter_form[@field]}
        multiple={true}
        class="max-h-100 overflow-y-auto grid grid-cols-1 sm:grid-cols-1 space-y-1"
        container_attrs={[
          id: "filter-#{@field}-scroll",
          "phx-viewport-bottom": @page < @max_page && JS.push("next_page", target: @myself)
        ]}
        options={Enum.map(@options, fn {value, count} -> {{value, format_number(count)}, value} end)}
      />
    </div>
    """
  end
end

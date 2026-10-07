defmodule DpulCollectionsWeb.Search.ScrollFilter do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def mount(socket), do: {:ok, assign(socket, query: "")}

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_options()}
  end

  def handle_event("search", %{"filter_query" => query}, socket) do
    {:noreply, socket |> assign(query: query) |> assign_options()}
  end

  defp assign_options(
         %{assigns: %{query: query, filter: filter, filter_form: form, field: field}} = socket
       ) do
    q = query |> String.trim() |> String.downcase()

    visible =
      if q == "",
        do: filter.data,
        else: Enum.filter(filter.data, fn {v, _} -> String.contains?(String.downcase(v), q) end)

    visible_values = MapSet.new(visible, fn {v, _} -> String.downcase(v) end)

    hidden_selected =
      List.wrap(form[field].value)
      |> Enum.reject(&(String.downcase(&1) in visible_values))

    assign(socket, options: visible, hidden_selected: hidden_selected)
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
          phx-change="search"
          phx-target={@myself}
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
        options={Enum.map(@options, fn {value, count} -> {{value, format_number(count)}, value} end)}
      />
    </div>
    """
  end
end

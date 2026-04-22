defmodule DpulCollectionsWeb.SearchLive.FilterSection do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.SearchLive

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "border border-rust/20 rounded-lg overflow-hidden bg-white",
        length(@filter_data) == 0 && "hidden"
      ]}
    >
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
        <span>{Gettext.gettext(DpulCollectionsWeb.Gettext, @filter_label)}</span>
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
          filter_label={@filter_label}
          filter_data={@filter_data}
          filter_form_name={@filter_form_name}
          filter_form_value={@filter_form_value}
          year_form={@year_form}
          filter_configuration={SearchLive.filter_configuration()[@field]}
          myself={@myself}
        />
      </div>
    </div>
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
    <div id={"search-#{@field}"} phx-hook="DpulCollectionsWeb.SearchLive.SearchFilter" class="pt-3">
      <div class="relative mb-2" phx-update="ignore" id={"search-wrapper-#{@field}"}>
        <label for={"filter-#{@field}-search"} class="sr-only">
          {gettext("Search")} {Gettext.gettext(DpulCollectionsWeb.Gettext, @filter_label)} {gettext(
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
        name={@filter_form_name}
        value={@filter_form_value}
        multiple={true}
        class="max-h-100 overflow-y-auto grid grid-cols-1 sm:grid-cols-1 space-y-1"
        options={
          @filter_data
          |> Enum.map(fn {value, count} -> {{value, count}, value} end)
        }
      />
    </div>
    """
  end
end

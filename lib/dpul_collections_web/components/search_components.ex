defmodule DpulCollectionsWeb.SearchComponents do
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.CoreComponents 

  attr :collection_title, :string, default: ""
  attr :search_state, :map, default: %{}
  attr :action, :string, default: nil
  attr :phx_submit, :string, default: nil
  attr :phx_target, :any, default: nil

  def search_bar(assigns) do
    ~H"""
    <div class="subnav-bar cover-with-pane">
      <div class="search-container min-h-[48px] bg-search">
        <form
          id="search-form"
          class="grow group w-full h-full"
          action={@action}
          method={if @action, do: "get", else: nil}
          {if @action, do: %{}, else: %{"phx-submit" => @phx_submit, "phx-target" => @phx_target}}
        >
          <!-- Covers the JSON mapping for when search_state is empty or not -->
          <input
            :if={Enum.any?(@search_state)}
            type="hidden"
            name="search_state"
            value={JSON.encode!(@search_state)}
          />
          <div
            class={[
              "grid md:grid-rows-1 md:grid-cols-[1fr_min-content] items-stretch w-full h-full overflow-x-hidden",
              String.length(@collection_title) > 0 && "grid-rows-2 grid-cols-1",
              String.length(@collection_title) > 0 || "grid-rows-1 grid-cols-[1fr_min-content]"
            ]}
            role="search"
          >
            <div class="subnav-l-padding flex items-center grow">
              <span class="flex-none">
                <.icon name="hero-magnifying-glass" class="h-8 w-8 icon" />
              </span>
              <label for="q" class="sr-only">{gettext("Search")}</label>
              <input
                class="m-2 px-1 py-0 grow w-full h-full placeholder:text-dark-text/40 bg-transparent border-none placeholder:text-xl text-xl placeholder:font-bold"
                type="text"
                id="q"
                name="q"
                placeholder={gettext("Search")}
                dir="auto"
              />
            </div>

            <div class={[
              "subnav-buttons flex items-stretch justify-items-stretch space-x-1 text-sm md:text-base md:w-auto",
              String.length(@collection_title) > 0 && "w-[calc(100%+40px)]"
            ]}>
              <.primary_button
                :if={String.length(@collection_title) > 0}
                id="collection-search-button"
                type="submit"
                name="search"
                value={@collection_title}
                class="grow max-md:subnav-diagonal-left md:subnav-diagonal-middle h-[48px]"
              >
                {gettext("In this Collection")}
                <.icon name="hero-arrow-turn-down-left" class="h-4/7 ml-1 hidden md:inline" />
              </.primary_button>

              <.primary_button
                id="search-button"
                type="submit"
                name="search"
                value="all"
                class={[
                  "grow subnav-diagonal-right h-[48px]",
                  "subnav-r-padding",
                  String.length(@collection_title) > 0 && "subnav-diagonal-right-pair"
                ]}
              >
                {search_label(@collection_title)}
              </.primary_button>
            </div>
          </div>
        </form>
      </div>
      <.content_separator />
    </div>
    """
  end

  defp search_label(""), do: gettext("Search")
  defp search_label(_), do: gettext("Search all")
end
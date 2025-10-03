defmodule DpulCollectionsWeb.CollectionsLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.Collection

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    collection = Collection.from_slug(slug)

    case collection do
      nil ->
        raise DpulCollectionsWeb.CollectionsLive.NotFoundError

      _ ->
        socket =
          assign(socket,
            page_title: collection.title,
            collection: collection
          )

        {:noreply, socket}
    end
  end

  defp pill_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-3 mb-2">
        <h2 id={"#{@container_id}-header"} class="text-sm font-medium">{@title}</h2>
      </div>
      <div
        phx-hook="ResponsivePills"
        id={@container_id}
      >
        <ul
          aria-labelledby={"#{@container_id}-header"}
          class="group max-h-[2.5rem] [&.expanded]:max-h-none flex flex-wrap gap-2 overflow-hidden"
        >
          <%= for {{name, count}, idx} <- Enum.with_index(@items) do %>
            <li
              aria-setsize={length(@items) + 2}
              aria-posinset={idx + 1}
              class={"pill-item #{@pill_class} group-[.expanded]:block px-3 py-1.5 rounded-full"}
            >
              <span class="text-xs">{name} ({count})</span>
            </li>
          <% end %>
          <li class={"hidden group-[.expanded]:block less-button px-3 py-1.5 rounded-full #{@button_class}"}>
            <button class="w-full h-full cursor-pointer text-xs">
              Show less
            </button>
          </li>
          <li class={"more-button invisible group-[.expanded]:invisible less-button px-3 py-1.5 rounded-full #{@button_class}"}>
            <button class="w-full h-full cursor-pointer text-xs">
              +<span class="more-count">{length(@items)}</span> more
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} content_class={}>
      <div class="[&>*:nth-child(odd)]:bg-background [&>*:nth-child(even)]:bg-secondary grid grid-flow-row auto-rows-max">
        <!-- Hero Section -->
        <div class="relative overflow-hidden">
          <div class="home-content-area page-y-padding">
            <div class="grid lg:grid-cols-2 gap-8 items-center">
              <!-- Left Column: Content -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <p class="text-accent font-semibold text-xl uppercase tracking-wide">
                    Digital Collection
                  </p>
                  <h1 class="flex-grow-1 text-4xl lg:text-4xl font-bold">
                    {@collection.title |> hd}
                  </h1>
                  <div class="flex flex-wrap gap-4">
                    <div class="flex items-center text-dark-text gap-2">
                      <div class="bg-light-accent rounded-full px-3 py-1">
                        {@collection.item_count} Items
                      </div>
                      <div class="bg-light-accent rounded-full px-3 py-1">
                        {length(@collection.languages)} Languages
                      </div>
                      <div class="bg-light-accent rounded-full px-3 py-1">
                        {length(@collection.geographic_origins)} Locations
                      </div>
                    </div>
                  </div>
                </div>
                <p class="text-xl leading-relaxed">
                  {@collection.tagline}
                </p>

                <div class="flex flex-wrap gap-4 pt-4">
                  <.primary_button
                    href={~p"/search?#{%{filter: %{project: @collection.title |> hd}}}"}
                    class="btn-primary"
                  >
                    Browse Collection
                  </.primary_button>

                  <button
                    phx-click={
                      JS.toggle_class(
                        "expanded",
                        to: "#collection-description"
                      )
                    }
                    class="btn-secondary"
                  >
                    Learn More
                  </button>
                </div>

                <div class="grid grid-cols-1 lg:grid-cols-1 gap-6">
                  <.pill_section
                    title="Subject Areas"
                    unit="categories"
                    items={@collection.categories}
                    container_id="categories-container"
                    pill_class="bg-secondary"
                    button_class="bg-secondary/80 hover:bg-secondary/60"
                  />

                  <.pill_section
                    title="Genres"
                    unit="genres"
                    items={@collection.genres}
                    container_id="genres-container"
                    pill_class="bg-cloud"
                    button_class="bg-cloud/80 hover:bg-cloud/60"
                  />
                </div>
              </div>
              <!-- Right Column: Featured Items Mosaic -->
              <div id="collection-mosaic" class="self-start h-120 relative">
                <div class="absolute inset-0 grid grid-cols-2 gap-2 w-full h-full">
                  <.link
                    :for={item <- @collection.featured_items}
                    href={item.url}
                    class="card p-2 bg-background min-h-0 min-w-0"
                    aria-label={"View #{item.title |> hd}"}
                  >
                    <div class="h-full w-full">
                      <img
                        src={"#{item.primary_thumbnail_service_url}/full/!#{item.primary_thumbnail_width},#{item.primary_thumbnail_height}/0/default.jpg"}
                        width={item.primary_thumbnail_width}
                        height={item.primary_thumbnail_height}
                        class="object-cover object-top h-full w-full"
                        alt={item.title |> hd}
                      />
                    </div>
                  </.link>
                </div>
              </div>
            </div>

            <div
              id="collection-description"
              class="bg-background page-t-padding overflow-hidden group"
            >
              <div class="[&_a]:text-accent transition-all duration-500 w-full text-lg max-h-0 invisible group-[.expanded]:visible group-[.expanded]:max-h-300">
                <div class="leading-relaxed">
                  {@collection.description |> raw}
                </div>
              </div>
            </div>
          </div>
          <.content_separator />
        </div>
        <!-- Recently Updated Items -->
        <.browse_item_row
          :if={length(@collection.recently_updated) > 0}
          id="recent-items"
          layout="home-content-area"
          items={@collection.recently_updated}
          title="Recently Updated Items"
          more_link={
            ~p"/search?#{%{filter: %{project: @collection.title |> hd}, sort_by: "recently_updated"}}"
          }
          show_images={[]}
          added?={true}
        >
          <p class="my-2">
            Explore the latest additions to our growing collection for {@collection.title |> hd}.
          </p>
        </.browse_item_row>
        <!-- Contributors -->
        <div
          :if={length(@collection.contributors) > 0}
          class="w-full home-content-area page-y-padding page-x-padding flex flex-col gap-4"
        >
          <h2 class="heading text-2xl">Contributors</h2>
          <div class="grid grid-flow-col auto-cols-fr">
            <div
              :for={contributor <- @collection.contributors}
              class="item card max-w-[400px]"
            >
              <div class="grid-rows-2 bg-sage-100 grid gap-0">
                <div class={[
                  "bg-search flex justify-center relative"
                ]}>
                  <img
                    src={contributor.logo}
                    class="object-fit"
                    alt=""
                  />
                </div>
                <div class="flex flex-col gap-2 p-4">
                  <div class="flex flex-wrap flex-row justify-between">
                    <.link
                      href={contributor.url}
                      target="_blank"
                      class="before:content-[''] before:absolute before:inset-0 before:z-[1]"
                    >
                      <h2 dir="auto flex-grow">
                        {contributor.label}
                      </h2>
                    </.link>
                  </div>
                  <div class="text-base z-2">{contributor.description |> raw}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Browse All Section -->
        <div class="text-dark-text w-full page-y-padding page-x-padding">
          <div class="home-content-area text-center">
            <h2 class="text-3xl font-bold mb-4">Ready to Explore?</h2>
            <p class="text-xl mb-8">
              Sort, filter, and search through the entirety of {@collection.title |> hd}.
            </p>
            <.primary_button
              href={~p"/search?#{%{filter: %{project: @collection.title |> hd}}}"}
              class="btn-primary text-lg px-8 py-4"
            >
              Browse All Items
            </.primary_button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

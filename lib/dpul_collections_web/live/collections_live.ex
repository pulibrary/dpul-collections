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
        <h2 id={"#{@container_id}-header"} class="text-sm font-medium text-wafer-pink">{@title}</h2>
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
    <Layouts.app flash={@flash}>
      <div class="grid grid-flow-row auto-rows-max">
        <!-- Hero Section -->
        <div class="home-content-area relative overflow-hidden">
          <div class="home-content-area left-[15%] absolute z-10">
            <img src="/images/triangle-mosaic.png" alt='' class="mx-auto w-xl" />
          </div>
          <div class="home-content-area space-y-2 relative z-30">
            <p class="text-accent font-semibold text-xl uppercase tracking-wide">
              Digital Collection
            </p>
            <h1 class="flex-grow-1 text-4xl lg:text-6xl font-[1000]">
              {@collection.title |> hd}
            </h1>
          </div>
          <div class='home-content-area page-y-padding relative z-30'>
            <div class="grid grid-cols-2 gap-0 grid-cols-[auto_60%]">
              <!-- Left Column: Content -->
              <div>
                <div class="w-full relative z-30">
                  <div class="w-full h-full bg-white opacity-75 absolute z-40">
                    
                  </div>
                  <div class="flex flex-wrap gap-4 p-5 relative z-50">
                    <p class="text-lg font-semibold text-dark-text italic font-serif">
                      The South Asian Ephemera Collection is an openly accessible repository of items that spans a variety of subjects and languages and supports research, teaching, and private study. Newly acquired materials are digitized and added on an ongoing basis.  
                      {@collection.tagline}
                    </p>
                    <div class="flex items-center text-dark-text gap-2">
                      <div class="text-sm bg-cloud rounded-full px-3 py-1">
                        {@collection.item_count} Items
                      </div>
                      <div class="text-sm bg-cloud rounded-full px-3 py-1">
                        {length(@collection.languages)} Languages
                      </div>
                      <div class="text-sm bg-cloud rounded-full px-3 py-1">
                        {length(@collection.geographic_origins)} Locations
                      </div>
                    </div>
                  </div>
                </div>
                <div class="flex flex-wrap gap-4 pt-4">
                  <button
                    phx-click={
                      JS.toggle_class(
                        "expanded",
                        to: "#collection-description"
                      )
                    }
                    class="btn-secondary bg-dark-gray text-light-text"
                  >
                    {gettext("Learn More")}
                  </button>
                </div>
              </div>
              <!-- Right Column: Featured Items Mosaic -->
              <div id="collection-mosaic" class="self-start h-120 relative">
                <div class="w-full h-full relative">
                  <.primary_button
                    href={~p"/search?#{%{filter: %{project: [@collection.title |> hd]}}}"}
                    class="btn-primary absolute bottom-[5%] right-0"
                  >
                    {gettext("Browse Collection")}
                  </.primary_button>
                  <%= for {item, index} <-  Enum.with_index(@collection.featured_items) do %>
                    <.link 
                      href={item.url}
                      class={"card w-[100%] p-2 bg-white min-h-0 min-w-0 absolute z-[#{index}]"}
                      aria-label={"View #{item.title |> hd}"}             
                    >
                      <div class="max-h-90 h-full w-full overflow-hidden">
                        <img
                          src={"#{item.primary_thumbnail_service_url}/full/!#{item.primary_thumbnail_width},#{item.primary_thumbnail_height}/0/default.jpg"}
                          width={item.primary_thumbnail_width}
                          height={item.primary_thumbnail_height}
                          class="object-cover object-top h-full w-full"
                          alt={item.title |> hd}
                        />
                      </div>
                    </.link>
                  <% end %>
                </div>
                
              </div>
            </div>
          </div>
        </div>
        <!-- Learn More -->
        <div class="grid-flow-row auto-rows-max bg-dark-gray py-6">
          <div id="collection-description" class="overflow-hidden group home-content-area grid grid-cols-2 gap-0 grid-cols-[60%_auto]">
            <div>
              <h2 class="heading text-4xl pb-4 text-wafer-pink py-6">Learn More</h2>
            </div>
            <div>
              <div class="[&_a]:text-accent transition-all duration-500 w-full text-lg max-h-0 invisible group-[.expanded]:visible group-[.expanded]:max-h-300 page-t-padding">
                <div class="leading-relaxed">
                  {@collection.description |> raw}
                </div>
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
          </div>
        </div>
        <.content_separator />
        <!-- Recently Updated Items -->
        <.browse_item_row
          :if={length(@collection.recently_added) > 0}
          id="recent-items"
          layout="home-content-area"
          items={@collection.recently_added}
          title={gettext("Recently Added Items")}
          more_link={
            ~p"/search?#{%{filter: %{project: [@collection.title |> hd]}, sort_by: "recently_added"}}"
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
          class="bg-dark-background w-full home-content-area page-y-padding page-x-padding flex flex-col"
          id="contributors"
        >
          <h2 class="heading text-2xl pb-4">Contributors</h2>
          <div class="flex flex-wrap gap-4">
            <div
              :for={contributor <- @collection.contributors}
              class="item card flex basis-full first:grow lg:basis-[calc(50%-0.5rem)]"
            >
              <div class="h-full grid-rows-2 bg-sage-100 grid sm:grid-rows-1 sm:grid-cols-6 gap-0">
                <div class={[
                  "search-thumbnail",
                  "row-span-2 col-span-1",
                  "bg-search flex items-center justify-center relative",
                  "h-full"
                ]}>
                  <div class="w-full flex items-center overflow-hidden justify-center gap-2 h-[150px] p-2">
                    <img
                      src={contributor.logo}
                      class="object-cover max-w-full max-h-full"
                      alt=""
                    />
                  </div>
                </div>
                <div class="metadata sm:col-span-5 flex flex-col gap-2 sm:gap-4 p-4">
                  <div class="flex flex-wrap flex-row sm:flex-row justify-between">
                    <.link
                      href={contributor.url}
                      target="_blank"
                      class="before:content-[''] before:absolute before:inset-0 before:z-[1]"
                    >
                      <h3 dir="auto" class="w-full font-bold text-xl flex-grow sm:w-fit">
                        {contributor.label}
                      </h3>
                    </.link>
                  </div>
                  <div class="text-base">{contributor.description |> raw}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

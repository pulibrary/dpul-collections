defmodule DpulCollectionsWeb.CollectionsLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.{Item, Collection}

  def mount(_params, _session, socket) do
    collection = get_collection("sae")

    socket =
      assign(socket,
        page_title: collection.title,
        collection: collection,
        recent_items: get_recent_collection_items()
      )

    {:ok, socket}
  end

  def get_collection(_slug) do
    Collection.from_slug("sae")
  end

  # Implement filters into Solr.recently_updated
  defp get_recent_collection_items do
    [
      %{
        id: "77ba4ea4-ce03-4a63-b0ee-a1a5b9cd746c",
        title: ["Migration from North-Eastern region to Bangalore: level and trend analysis"],
        date: "2016",
        geographic_origin: "India",
        file_count: 24,
        primary_thumbnail_service_url:
          "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file",
        image_service_urls: [
          "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file"
        ],
        primary_thumbnail_width: 350,
        primary_thumbnail_height: 350,
        genre: "Reports",
        url: "/item/77ba4ea4-ce03-4a63-b0ee-a1a5b9cd746c",
        updated_at: "2024-01-15T10:30:00Z"
      },
      %{
        id: "9bb5fedf-bdde-4207-abd3-1ade3e190d94",
        title: ["Please fasten your seat belts! We are passing through turbulent weather"],
        date: "2011",
        geographic_origin: "India",
        file_count: 11,
        primary_thumbnail_service_url:
          "https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file",
        image_service_urls: [
          "https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file"
        ],
        primary_thumbnail_width: 350,
        primary_thumbnail_height: 350,
        genre: "Brochures",
        url: "/item/9bb5fedf-bdde-4207-abd3-1ade3e190d94",
        updated_at: "2024-01-12T14:22:00Z"
      },
      %{
        id: "ec477e9c-eff1-4945-b438-e5e7fdcb55f9",
        title: ["Qissa soi storytelling: behrupiya storytelling tradition of Delhi"],
        date: "2018",
        geographic_origin: "India",
        file_count: 3,
        primary_thumbnail_service_url:
          "https://iiif-cloud.princeton.edu/iiif/2/6f%2F85%2Fde%2F6f85deaa645d480d8564916ac887be9a%2Fintermediate_file",
        image_service_urls: [
          "https://iiif-cloud.princeton.edu/iiif/2/6f%2F85%2Fde%2F6f85deaa645d480d8564916ac887be9a%2Fintermediate_file"
        ],
        primary_thumbnail_width: 350,
        primary_thumbnail_height: 350,
        genre: "Flyers",
        url: "/item/ec477e9c-eff1-4945-b438-e5e7fdcb55f9",
        updated_at: "2024-01-18T09:15:00Z"
      },
      %{
        id: "6fb2af84-6a4f-401d-8c7e-5787633876f5",
        title: ["تغیر پذیر حالت میں تفقه کے تقاضے اور هم"],
        geographic_origin: "India",
        file_count: 22,
        primary_thumbnail_service_url:
          "https://iiif-cloud.princeton.edu/iiif/2/e1%2F39%2Fe6%2Fe139e69b8421409392c35fdf936d8895%2Fintermediate_file",
        image_service_urls: [
          "https://iiif-cloud.princeton.edu/iiif/2/e1%2F39%2Fe6%2Fe139e69b8421409392c35fdf936d8895%2Fintermediate_file"
        ],
        primary_thumbnail_width: 350,
        primary_thumbnail_height: 350,
        genre: "Booklets",
        url: "/item/6fb2af84-6a4f-401d-8c7e-5787633876f5",
        updated_at: "2024-01-10T16:45:00Z"
      }
    ]
    |> Enum.map(&struct(Item, &1))
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
      <div class="[&>*:nth-child(odd)]:bg-background [&>*:nth-child(event)]:bg-secondary grid grid-flow-row auto-rows-max">
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
              <div class="self-start h-120 relative">
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
          id="recent-sae-items"
          layout="home-content-area"
          items={@recent_items}
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
        <!-- Browse All Section -->
        <div class="text-dark-text w-full page-y-padding page-x-padding">
          <div class="home-content-area text-center">
            <h2 class="text-3xl font-bold mb-4">Ready to Explore?</h2>
            <p class="text-xl mb-8">
              Sort, filter, and search through the entirety of {@collection.title |> hd}.
            </p>
            <.primary_button
              href={~p"/search?#{%{filter: %{project: @collection.title}}}"}
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

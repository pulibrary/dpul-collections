defmodule DpulCollectionsWeb.CollectionsLive do
  alias DpulCollectionsWeb.BrowseItem
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
        recent_items: get_recent_collection_items(),
        featured_items: get_featured_items()
      )

    {:ok, socket}
  end

  def get_collection(_slug) do
    %Collection{
      id: "f99af4de-fed4-4baa-82b1-6e857b230306",
      slug: "sae",
      title: "South Asian Ephemera",
      tagline:
        "Discover voices of change across South Asia through contemporary pamphlets, flyers, and documents that capture the region's social movements, politics, and cultural expressions.",
      description: """
      The South Asian Ephemera Collection complements Princeton's already robust Digital Archive of Latin American and Caribbean Ephemera. The goal of the collection is to provide a diverse selection of resources that span a variety of subjects and languages and support interdisciplinary scholarship in South Asian Studies.
      At present, the collection is primarily composed of contemporary ephemera and items from the latter half of the twentieth century, though users will also find items originating from earlier dates. Common genres in the collection include booklets, pamphlets, leaflets, and flyers. These items were produced by a variety of individuals and organizations including political parties, non-governmental organizations, public policy think tanks, activists, and others and were meant to promote their views, positions, agendas, policies, events, and activities.
      Every effort is being made to represent each country in the region. As the collection grows over time, PUL will provide increasingly balanced coverage of the area.
      """,
      # I don't really know if these should be in here, but for now it's probably fine.
      item_count: 3_087,
      # These should probably come from facet data.
      categories: get_categories(),
      genres: get_genres(),
      languages: get_languages(),
      geographic_origins: get_geographic_origins()
    }
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

  defp get_featured_items do
    get_recent_collection_items()
  end

  defp get_categories do
    [
      {"Politics and government", 1166},
      {"Religion", 767},
      {"Socioeconomic conditions and development", 527},
      {"Gender and sexuality", 473},
      {"Human and Civil Rights", 432},
      {"Arts and culture", 372},
      {"Minorities, ethnic and racial groups", 321},
      {"Economics", 284},
      {"Environment and ecology", 262},
      {"Education", 254},
      {"Agrarian and rural issues", 249},
      {"History", 220},
      {"Children and youth", 182},
      {"Health", 168},
      {"Labor", 158},
      {"Tourism", 82}
    ]
  end

  defp get_genres do
    [
      {"Booklets", 758},
      {"Reports", 559},
      {"Serials", 447},
      {"Pamphlets", 334},
      {"News clippings", 279},
      {"Posters", 260},
      {"Brochures", 182},
      {"Flyers", 54},
      {"Leaflets", 44},
      {"Manuscripts", 41},
      {"Pedagogical materials", 37},
      {"Electoral paraphernalia", 17},
      {"Stickers", 11},
      {"Correspondence", 8},
      {"Postcards", 6},
      {"Advertisements", 4},
      {"Maps", 3},
      {"Calendars", 2},
      {"Forms", 2},
      {"Games", 1}
    ]
  end

  defp get_languages do
    [
      {"English", 2015},
      {"Urdu", 320},
      {"Hindi", 226},
      {"Sinhala", 143},
      {"Nepali", 129},
      {"Telugu", 118},
      {"Assamese", 72},
      {"Tamil", 67},
      {"Bengali", 54},
      {"Arabic", 47},
      {"Gujarati", 26},
      {"Oriya", 25},
      {"Sanskrit", 14},
      {"Marathi", 12},
      {"Persian", 12},
      {"Kannada", 8},
      {"Sinhala | Sinhalese", 7},
      {"Dzongkha", 4},
      {"Esperanto", 4},
      {"Malayalam", 4},
      {"Pushto", 4},
      {"Italian", 3},
      {"Sino-Tibetan languages", 3},
      {"French", 2},
      {"Pali", 2},
      {"Panjabi", 2},
      {"Spanish", 2},
      {"Chhattisgarhi", 1},
      {"Divehi", 1},
      {"Divehi | Dhivehi | Maldivian", 1},
      {"German", 1},
      {"Indic languages", 1},
      {"Nepal Bhasa", 1},
      {"Panjabi | Punjabi", 1},
      {"Pushto | Pashto", 1}
    ]
  end

  defp get_geographic_origins do
    [
      {"India", 1433},
      {"Sri Lanka", 610},
      {"Pakistan", 561},
      {"Nepal", 240},
      {"Bangladesh", 47},
      {"United States", 36},
      {"Afghanistan", 27},
      {"Maldives", 17},
      {"Bhutan", 14},
      {"United Kingdom", 9},
      {"Switzerland", 5},
      {"India--Delhi", 4},
      {"India--West Bengal", 4},
      {"Italy", 3},
      {"Netherlands", 3},
      {"India--Maharashtra", 2},
      {"India--Punjab", 2},
      {"Japan", 2},
      {"No place, unknown, or undetermined", 2},
      {"Australia", 1},
      {"China", 1},
      {"Denmark", 1},
      {"France", 1},
      {"Germany", 1},
      {"India--Andhra Pradesh", 1},
      {"India--Chhattīsgarh", 1},
      {"India--Jharkhand", 1},
      {"India--Karnataka", 1},
      {"India--Rajasthan", 1},
      {"India--Telangana", 1},
      {"India--Uttar Pradesh", 1},
      {"South Africa", 1},
      {"Tarai (India and Nepal)", 1}
    ]
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
              class={"pill-item #{@pill_class} group-[.expanded]:block hover:bg-sage-300 px-3 py-1.5 rounded-full duration-200"}
            >
              <span class="text-xs">{name} ({count})</span>
            </li>
          <% end %>
          <li class="hidden group-[.expanded]:block less-button">
            <button class="cursor-pointer bg-sage-100 hover:bg-sage-200 px-3 py-1.5 rounded-full text-xs h-full">
              Show less
            </button>
          </li>
          <li class="more-button group-[.expanded]:invisible">
            <button class="cursor-pointer bg-sage-100 hover:bg-sage-200 px-3 py-1.5 rounded-full text-xs h-full">
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
      <div class="grid grid-flow-row auto-rows-max">
        <!-- Hero Section -->
        <div class="bg-background relative overflow-hidden">
          <div class="home-content-area page-y-padding">
            <div class="grid lg:grid-cols-2 gap-8 items-center">
              <!-- Left Column: Content -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <p class="text-accent font-semibold text-xl uppercase tracking-wide">
                    Digital Collection
                  </p>
                  <h1 class="flex-grow-1 text-4xl lg:text-4xl font-bold">
                    {@collection.title}
                  </h1>
                  <div class="flex flex-wrap gap-4">
                    <div class="flex items-center text-dark-text gap-2">
                      <div class="bg-accent/20 rounded-full px-3 py-1">
                        {@collection.item_count} Items
                      </div>
                      <div class="bg-accent/20 rounded-full px-3 py-1">
                        {length(@collection.languages)} Languages
                      </div>
                      <div class="bg-accent/20 rounded-full px-3 py-1">
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
                    href={~p"/search?#{%{filter: %{project: @collection.title}}}"}
                    class="btn-primary"
                  >
                    Browse Collection
                  </.primary_button>

                  <button
                    phx-click={
                      JS.toggle(
                        to: "#collection-description",
                        time: 500,
                        in: {"duration-500", "max-h-0", "max-h-300"},
                        out: {"duration-500 block", "max-h-300", "max-h-0"}
                      )
                    }
                    class="btn-secondary text-dark-text hover:bg-cloud"
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
                    pill_class="bg-sage-200"
                  />

                  <.pill_section
                    title="Genres"
                    unit="genres"
                    items={@collection.genres}
                    container_id="genres-container"
                    pill_class="bg-cloud"
                  />
                </div>
              </div>
              <!-- Right Column: Featured Items Mosaic -->
              <div class="self-start">
                <div class="py-4 grid grid-cols-2 gap-2 transform rotate-2 hover:rotate-0 transition-transform duration-500">
                  <%= for {item, index} <- Enum.with_index(Enum.take(@featured_items, 4)) do %>
                    <div class={[
                      "card hover:scale-105 transition-transform duration-300 cursor-pointer",
                      case rem(index, 3) do
                        0 -> "translate-y-4"
                        1 -> "-translate-y-2"
                        2 -> "translate-y-6"
                      end
                    ]}>
                      <.link navigate={item.url}>
                        <div class="w-full h-40 object-cover object-top rounded-t overflow-hidden">
                          <BrowseItem.thumb
                            item={item}
                            thumb={BrowseItem.thumbnail_service_url(item)}
                          />
                        </div>
                        <div class="p-2 bg-background">
                          <p class="text-xs font-medium truncate">{item.title}</p>
                        </div>
                      </.link>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <div
              id="collection-description"
              class="transition-[max-height] bg-background page-t-padding overflow-hidden hidden"
            >
              <div class="w-full text-lg">
                <div class="">
                  <p
                    :for={description_paragraph <- String.split(@collection.description, "\n")}
                    class="leading-relaxed not-first:mt-4"
                  >
                    {description_paragraph}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
        <.content_separator />
        <!-- Recently Updated Items -->
        <.browse_item_row
          id="recent-sae-items"
          layout="home-content-area"
          color="bg-secondary"
          items={@recent_items}
          title="Recently Updated Items"
          more_link={
            ~p"/search?#{%{filter: %{project: @collection.title}, sort_by: "recently_updated"}}"
          }
          show_images={[]}
          added?={true}
        >
          <p class="my-2">
            Explore the latest additions to our growing collection for {@collection.title}.
          </p>
        </.browse_item_row>
        <!-- Browse All Section -->
        <div class="bg-background text-dark-text w-full page-y-padding page-x-padding">
          <div class="home-content-area text-center">
            <h2 class="text-3xl font-bold mb-4">Ready to Explore?</h2>
            <p class="text-xl mb-8">
              Sort, filter, and search through the entirety of {@collection.title}.
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

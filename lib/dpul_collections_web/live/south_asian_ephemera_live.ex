defmodule DpulCollectionsWeb.SouthAsianEphemeraLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.Item

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "South Asian Ephemera",
        show_description: false,
        recent_items: get_recent_collection_items(),
        featured_items: get_featured_items()
      )

    {:ok, socket}
  end

  def handle_event("toggle_description", _, socket) do
    {:noreply, assign(socket, show_description: !socket.assigns.show_description)}
  end

  defp get_recent_collection_items do
    # Simulate getting recent items from the South Asian Ephemera collection
    # In a real implementation, this would query Solr with collection filters
    [
      %{
        id: "sae001",
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
        url: "/item/sae001",
        updated_at: "2024-01-15T10:30:00Z"
      },
      %{
        id: "sae002",
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
        url: "/item/sae002",
        updated_at: "2024-01-12T14:22:00Z"
      },
      %{
        id: "sae003",
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
        url: "/item/sae003",
        updated_at: "2024-01-18T09:15:00Z"
      },
      %{
        id: "sae004",
        title: ["Pokhara Darpan: Annual Bulletin, Issue 17, 2068 Bhadra, September 2011"],
        date: "2011",
        geographic_origin: "Nepal",
        file_count: 67,
        primary_thumbnail_service_url:
          "https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file",
        image_service_urls: [
          "https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file"
        ],
        primary_thumbnail_width: 350,
        primary_thumbnail_height: 350,
        genre: "Serials",
        url: "/item/sae004",
        updated_at: "2024-01-10T16:45:00Z"
      }
    ]
    |> Enum.map(&struct(Item, &1))
  end

  defp get_featured_items do
    # Get a selection of visually interesting items for the hero section
    [
      %{
        id: "sae001",
        image_url:
          "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Migration from North-Eastern region to Bangalore: level and trend analysis"
      },
      %{
        id: "sae002",
        image_url:
          "https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Please fasten your seat belts! We are passing through turbulent weather"
      },
      %{
        id: "sae003",
        image_url:
          "https://iiif-cloud.princeton.edu/iiif/2/6f%2F85%2Fde%2F6f85deaa645d480d8564916ac887be9a%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Qissa soi storytelling: behrupiya storytelling tradition of Delhi"
      },
      %{
        id: "sae004",
        image_url:
          "https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Pokhara Darpan: Annual Bulletin, Issue 17, 2068 Bhadra, September 2011"
      },
      %{
        id: "sae005",
        image_url:
          "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Migration from North-Eastern region to Bangalore: level and trend analysis"
      },
      %{
        id: "sae006",
        image_url:
          "https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Pokhara Darpan: Annual Bulletin, Issue 17, 2068 Bhadra, September 2011"
      }
    ]
  end

  defp get_categories do
    [
      {"Politics and government", 1166, "#politics-and-government"},
      {"Religion", 767, nil},
      {"Socioeconomic conditions and development", 527, nil},
      {"Gender and sexuality", 473, nil},
      {"Human and Civil Rights", 432, nil},
      {"Arts and culture", 372, nil},
      {"Minorities, ethnic and racial groups", 321, nil},
      {"Economics", 284, nil},
      {"Environment and ecology", 262, nil},
      {"Education", 254, nil},
      {"Agrarian and rural issues", 249, nil},
      {"History", 220, nil},
      {"Children and youth", 182, nil},
      {"Health", 168, nil},
      {"Labor", 158, nil},
      {"Tourism", 82, nil}
    ]
  end

  defp get_genres do
    [
      {"Booklets", 758, nil},
      {"Reports", 559, nil},
      {"Serials", 447, nil},
      {"Pamphlets", 334, nil},
      {"News clippings", 279, nil},
      {"Posters", 260, nil},
      {"Brochures", 182, nil},
      {"Flyers", 54, nil},
      {"Leaflets", 44, nil},
      {"Manuscripts", 41, nil},
      {"Pedagogical materials", 37, nil},
      {"Electoral paraphernalia", 17, nil},
      {"Stickers", 11, nil},
      {"Correspondence", 8, nil},
      {"Postcards", 6, nil},
      {"Advertisements", 4, nil},
      {"Maps", 3, nil},
      {"Calendars", 2, nil},
      {"Forms", 2, nil},
      {"Games", 1, nil}
    ]
  end

  defp get_languages do
    [
      {"English", 2015, nil},
      {"Urdu", 320, nil},
      {"Hindi", 226, nil},
      {"Sinhala", 143, nil},
      {"Nepali", 129, nil},
      {"Telugu", 118, nil},
      {"Assamese", 72, nil},
      {"Tamil", 67, nil},
      {"Bengali", 54, nil},
      {"Arabic", 47, nil},
      {"Gujarati", 26, nil},
      {"Oriya", 25, nil},
      {"Sanskrit", 14, nil},
      {"Marathi", 12, nil},
      {"Persian", 12, nil},
      {"Kannada", 8, nil},
      {"Sinhala | Sinhalese", 7, nil},
      {"Dzongkha", 4, nil},
      {"Esperanto", 4, nil},
      {"Malayalam", 4, nil},
      {"Pushto", 4, nil},
      {"Italian", 3, nil},
      {"Sino-Tibetan languages", 3, nil},
      {"French", 2, nil},
      {"Pali", 2, nil},
      {"Panjabi", 2, nil},
      {"Spanish", 2, nil},
      {"Chhattisgarhi", 1, nil},
      {"Divehi", 1, nil},
      {"Divehi | Dhivehi | Maldivian", 1, nil},
      {"German", 1, nil},
      {"Indic languages", 1, nil},
      {"Nepal Bhasa", 1, nil},
      {"Panjabi | Punjabi", 1, nil},
      {"Pushto | Pashto", 1, nil}
    ]
  end

  defp get_geographic_origins do
    [
      {"India", 1433, nil},
      {"Sri Lanka", 610, nil},
      {"Pakistan", 561, nil},
      {"Nepal", 240, nil},
      {"Bangladesh", 47, nil},
      {"United States", 36, nil},
      {"Afghanistan", 27, nil},
      {"Maldives", 17, nil},
      {"Bhutan", 14, nil},
      {"United Kingdom", 9, nil},
      {"Switzerland", 5, nil},
      {"India--Delhi", 4, nil},
      {"India--West Bengal", 4, nil},
      {"Italy", 3, nil},
      {"Netherlands", 3, nil},
      {"India--Maharashtra", 2, nil},
      {"India--Punjab", 2, nil},
      {"Japan", 2, nil},
      {"No place, unknown, or undetermined", 2, nil},
      {"Australia", 1, nil},
      {"China", 1, nil},
      {"Denmark", 1, nil},
      {"France", 1, nil},
      {"Germany", 1, nil},
      {"India--Andhra Pradesh", 1, nil},
      {"India--Chhattīsgarh", 1, nil},
      {"India--Jharkhand", 1, nil},
      {"India--Karnataka", 1, nil},
      {"India--Rajasthan", 1, nil},
      {"India--Telangana", 1, nil},
      {"India--Uttar Pradesh", 1, nil},
      {"South Africa", 1, nil},
      {"Tarai (India and Nepal)", 1, nil}
    ]
  end

  defp pill_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-3 mb-2">
        <h3 id={"#{@container_id}-header"} class="text-sm font-medium">{@title}</h3>
        <span class="text-xs">
          {length(@items)} {@unit}
        </span>
      </div>
      <div
        phx-hook="ResponsivePills"
        id={@container_id}
      >
        <ul
          aria-labelledby={"#{@container_id}-header"}
          class="group max-h-[2.5rem] [&.expanded]:max-h-none flex flex-wrap gap-2 overflow-hidden"
        >
          <%= for {{name, count, href}, idx} <- Enum.with_index(@items) do %>
            <li
              aria-setsize={length(@items) + 2}
              aria-posinset={idx + 1}
              class={"pill-item #{@pill_class} group-[.expanded]:block hover:bg-sage-300 px-3 py-1.5 rounded-full duration-200"}
            >
              <%= if href do %>
                <.link
                  href={href}
                  class="text-xs"
                >
                  {name} ({count})
                </.link>
              <% else %>
                <span class="text-xs">{name} ({count})</span>
              <% end %>
            </li>
          <% end %>
          <li class="hidden group-[.expanded]:block less-button">
            <button class="bg-sage-100 hover:bg-sage-200 px-3 py-1.5 rounded-full text-xs h-full">
              Show less
            </button>
          </li>
          <li class="more-button group-[.expanded]:invisible">
            <button class="bg-sage-100 hover:bg-sage-200 px-3 py-1.5 rounded-full text-xs h-full">
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
          <div class="home-content-area py-12">
            <div class="grid lg:grid-cols-2 gap-8 items-center">
              <!-- Left Column: Content -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <p class="text-accent font-semibold text-xl uppercase tracking-wide">
                    Digital Collection
                  </p>
                  <div class="flex gap-4">
                    <h1 class="text-4xl lg:text-4xl font-bold">
                      South Asian Ephemera
                    </h1>
                    <div class="flex items-center bg-accent/20 rounded-full px-3 py-1 text-dark-text">
                      3,087 Items
                    </div>
                  </div>
                </div>
                <p class="text-xl leading-relaxed">
                  Discover voices of change across South Asia through contemporary pamphlets,
                  flyers, and documents that capture the region's social movements, politics,
                  and cultural expressions.
                </p>

                <div class="flex flex-wrap gap-4 pt-4">
                  <.primary_button
                    href="/search?filter[project]=South+Asian+Ephemera"
                    class="btn-primary"
                  >
                    Browse Collection
                  </.primary_button>

                  <button
                    phx-click="toggle_description"
                    class="btn-secondary text-dark-text hover:bg-cloud"
                  >
                    Learn More
                  </button>
                </div>
              </div>
              <!-- Right Column: Featured Items Mosaic -->
              <div class="relative align-self-start">
                <div class="grid grid-cols-3 gap-2 transform rotate-2 hover:rotate-0 transition-transform duration-500">
                  <%= for {item, index} <- Enum.with_index(@featured_items) do %>
                    <div class={[
                      "card hover:scale-105 transition-transform duration-300 cursor-pointer",
                      case rem(index, 3) do
                        0 -> "translate-y-4"
                        1 -> "-translate-y-2"
                        2 -> "translate-y-6"
                      end
                    ]}>
                      <.link navigate={"/item/#{item.id}"}>
                        <img
                          src={item.image_url}
                          alt={item.title}
                          class="w-full h-24 object-cover rounded-t"
                        />
                        <div class="p-2 bg-background">
                          <p class="text-xs font-medium truncate">{item.title}</p>
                        </div>
                      </.link>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            <!-- Collection At a Glance Section -->
            <div class="w-full text-sm page-y-padding">
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <.pill_section
                  title="Subject Areas"
                  unit="categories"
                  items={get_categories()}
                  container_id="categories-container"
                  pill_class="bg-sage-200"
                />

                <.pill_section
                  title="Genres"
                  unit="genres"
                  items={get_genres()}
                  container_id="genres-container"
                  pill_class="bg-cloud"
                />

                <.pill_section
                  title="Languages"
                  unit="languages"
                  items={get_languages()}
                  container_id="languages-container"
                  pill_class="bg-wafer-pink"
                />

                <.pill_section
                  title="Geographic Origin"
                  unit="regions"
                  items={get_geographic_origins()}
                  container_id="geographic-origins-container"
                  pill_class="bg-sage-100"
                />
              </div>
            </div>

            <div class={[
              "bg-background transition-all duration-500 overflow-hidden",
              if(@show_description, do: "max-h-200", else: "max-h-0")
            ]}>
              <div class="w-full text-lg">
                <div class="">
                  <p class="leading-relaxed mb-4">
                    The South Asian Ephemera Collection complements Princeton's already robust Digital Archive of Latin American and Caribbean Ephemera. The goal of the collection is to provide a diverse selection of resources that span a variety of subjects and languages and support interdisciplinary scholarship in South Asian Studies.
                  </p>
                  <p class="leading-relaxed mb-4">
                    At present, the collection is primarily composed of contemporary ephemera and items from the latter half of the twentieth century, though users will also find items originating from earlier dates. Common genres in the collection include booklets, pamphlets, leaflets, and flyers. These items were produced by a variety of individuals and organizations including political parties, non-governmental organizations, public policy think tanks, activists, and others and were meant to promote their views, positions, agendas, policies, events, and activities.
                  </p>
                  <p class="leading-relaxed mb-4">
                    Every effort is being made to represent each country in the region. As the collection grows over time, PUL will provide increasingly balanced coverage of the area.
                  </p>
                  <div class="grid md:grid-cols-1 gap-6 mt-6">
                    <div>
                      <h3 class="text-lg font-semibold text-princeton-black mb-3">
                        Subject Areas Include:
                      </h3>
                      <ul class="text-sm space-y-1 columns-3">
                        <li>Agrarian and rural issues</li>
                        <li>Arts and culture</li>
                        <li>Children and youth</li>
                        <li>Economics</li>
                        <li>Education</li>
                        <li>Environment and ecology</li>
                        <li>Gender</li>
                        <li>Health</li>
                        <li>Human and civil rights</li>
                        <li>Labor</li>
                        <li>Minorities</li>
                        <li>Politics and government</li>
                        <li>Religion</li>
                        <li>Science and Technology</li>
                        <li>Urban issues</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Collection Description (Collapsible) -->

        <.content_separator />
        <!-- Recently Updated Items -->
        <.browse_item_row
          id="recent-sae-items"
          layout="content-area"
          color="bg-secondary"
          items={@recent_items}
          title="Recently Updated Items"
          more_link="/search?filter[project]=South+Asian+Ephemera&sort_by=recently_updated"
          show_images={[]}
          added?={true}
        >
          <p class="my-2">
            Explore the latest additions to our growing collection of South Asian ephemera.
          </p>
        </.browse_item_row>
        <!-- Politics and government -->
        <.browse_item_row
          id="politics-and-government"
          layout="content-area"
          color="bg-background"
          items={@recent_items}
          title="Top Subject: Politics and government"
          more_link="/search?filter[project]=South+Asian+Ephemera&filter[category]=Politics+and+government&sort_by=recently_updated"
          show_images={[]}
        >
        </.browse_item_row>
        <!-- Browse All Section -->
        <div class="bg-secondary text-dark-text w-full page-y-padding page-x-padding">
          <div class="content-area text-center">
            <h2 class="text-3xl font-bold mb-4">Ready to Explore?</h2>
            <p class="text-xl mb-8">
              Dive deep into thousands of documents that tell the story of South Asian societies.
            </p>
            <.primary_button
              href="/search?filter[project]=South+Asian+Ephemera"
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

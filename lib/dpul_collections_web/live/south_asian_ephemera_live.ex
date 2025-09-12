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
        primary_thumbnail_service_url: "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file",
        image_service_urls: ["https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file"],
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
        primary_thumbnail_service_url: "https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file",
        image_service_urls: ["https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file"],
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
        primary_thumbnail_service_url: "https://iiif-cloud.princeton.edu/iiif/2/6f%2F85%2Fde%2F6f85deaa645d480d8564916ac887be9a%2Fintermediate_file",
        image_service_urls: ["https://iiif-cloud.princeton.edu/iiif/2/6f%2F85%2Fde%2F6f85deaa645d480d8564916ac887be9a%2Fintermediate_file"],
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
        primary_thumbnail_service_url: "https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file",
        image_service_urls: ["https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file"],
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
        image_url: "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Migration Analysis Report"
      },
      %{
        id: "sae002", 
        image_url: "https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Travel Safety Brochure"
      },
      %{
        id: "sae003",
        image_url: "https://iiif-cloud.princeton.edu/iiif/2/6f%2F85%2Fde%2F6f85deaa645d480d8564916ac887be9a%2Fintermediate_file/full/!350,350/0/default.jpg", 
        title: "Storytelling Tradition Flyer"
      },
      %{
        id: "sae004",
        image_url: "https://iiif-cloud.princeton.edu/iiif/2/38%2F4e%2Fec%2F384eec1c6fcc4229be4acb2169b5ba29%2Fintermediate_file/full/!350,350/0/default.jpg",
        title: "Pokhara Community Bulletin"
      },
      %{
        id: "sae005",
        image_url: "https://iiif-cloud.princeton.edu/iiif/2/a2%2F30%2F20%2Fa23020f89dd645f1803be45dc9ff0d17%2Fintermediate_file/full/!200,300/0/default.jpg",
        title: "Policy Document"
      },
      %{
        id: "sae006", 
        image_url: "https://iiif-cloud.princeton.edu/iiif/2/7e%2F67%2F0e%2F7e670ec857c94ca5a6b2c4e195daaa9d%2Fintermediate_file/full/!200,300/0/default.jpg",
        title: "Cultural Event Poster"
      }
    ]
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} content_class={}>
      <div class="grid grid-flow-row auto-rows-max">
        <!-- Hero Section -->
        <div class="bg-sage-100 relative overflow-hidden">
          <div class="content-area py-12">
            <div class="grid lg:grid-cols-2 gap-8 items-center">
              <!-- Left Column: Content -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <p class="text-accent font-semibold text-sm uppercase tracking-wider">Digital Collection</p>
                  <h1 class="text-4xl lg:text-5xl font-bold text-princeton-black">South Asian Ephemera</h1>
                </div>
                
                <p class="text-xl text-dark-sage font-serif leading-relaxed">
                  Discover voices of change across South Asia through contemporary pamphlets, 
                  flyers, and documents that capture the region's social movements, politics, 
                  and cultural expressions.
                </p>
                
                <div class="flex flex-wrap gap-4 pt-4">
                  <.primary_button href="/search?filter[project]=South+Asian+Ephemera" class="btn-primary">
                    Browse Collection
                  </.primary_button>
                  
                  <button 
                    phx-click="toggle_description"
                    class="btn-secondary text-dark-text hover:bg-cloud"
                  >
                    Learn More
                  </button>
                </div>
                
                <div class="flex flex-wrap gap-2 text-sm">
                  <span class="bg-sage-200 text-dark-sage px-3 py-1 rounded-full">Politics</span>
                  <span class="bg-sage-200 text-dark-sage px-3 py-1 rounded-full">Culture</span>
                  <span class="bg-sage-200 text-dark-sage px-3 py-1 rounded-full">Social Issues</span>
                  <span class="bg-sage-200 text-dark-sage px-3 py-1 rounded-full">20+ Languages</span>
                </div>
              </div>
              
              <!-- Right Column: Featured Items Mosaic -->
              <div class="relative">
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
                          <p class="text-xs text-dark-sage font-medium truncate">{item.title}</p>
                        </div>
                      </.link>
                    </div>
                  <% end %>
                </div>
                
                <!-- Decorative elements -->
                <div class="absolute -top-4 -right-4 w-8 h-8 bg-accent rounded-full opacity-20"></div>
                <div class="absolute -bottom-6 -left-2 w-12 h-12 bg-sage-300 rounded-full opacity-30"></div>
              </div>
            </div>
          </div>
        </div>

        <!-- Collection Description (Collapsible) -->
        <div class={["bg-background transition-all duration-500 overflow-hidden", if(@show_description, do: "max-h-96", else: "max-h-0")]}>
          <div class="content-area py-8 border-t border-sage-200">
            <div class="max-w-4xl mx-auto prose prose-sage">
              <p class="text-lg font-serif leading-relaxed mb-4">
                The South Asian Ephemera Collection is a digital archive that aims to support 
                interdisciplinary scholarship in South Asian Studies. The collection consists 
                primarily of contemporary ephemera and items from the latter half of the 20th century.
              </p>
              
              <p class="font-serif leading-relaxed mb-4">
                This digital collection includes booklets, pamphlets, leaflets, and flyers produced 
                by political parties, NGOs, think tanks, activists, and other organizations. The goal 
                is to provide a diverse selection of resources that span a variety of subjects and 
                languages, representing each country in the South Asian region with balanced coverage 
                as the collection grows.
              </p>
              
              <div class="grid md:grid-cols-2 gap-6 mt-6">
                <div>
                  <h3 class="text-lg font-semibold text-princeton-black mb-3">Subject Areas Include:</h3>
                  <ul class="text-sm space-y-1 columns-2">
                    <li>• Agrarian and rural issues</li>
                    <li>• Arts and culture</li>
                    <li>• Children and youth</li>
                    <li>• Economics</li>
                    <li>• Education</li>
                    <li>• Environment and ecology</li>
                    <li>• Gender</li>
                    <li>• Health</li>
                    <li>• Human and civil rights</li>
                    <li>• Labor</li>
                    <li>• Minorities</li>
                    <li>• Politics and government</li>
                    <li>• Religion</li>
                    <li>• Science and Technology</li>
                    <li>• Urban issues</li>
                  </ul>
                </div>
                
                <div>
                  <h3 class="text-lg font-semibold text-princeton-black mb-3">Collection Highlights:</h3>
                  <ul class="text-sm space-y-2">
                    <li class="flex items-start gap-2">
                      <span class="text-accent">📚</span>
                      <span>Contemporary pamphlets and booklets</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="text-accent">🗳️</span>
                      <span>Political party materials</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="text-accent">🌍</span>
                      <span>NGO and activist publications</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="text-accent">🔬</span>
                      <span>Think tank research documents</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>

        <.content_separator />

        <!-- Recently Updated Items -->
        <.browse_item_row
          id="recent-sae-items"
          layout="content-area" 
          color="bg-sage-50"
          items={@recent_items}
          title="Recently Updated Items"
          more_link="/search?filter[project]=South+Asian+Ephemera&sort_by=recently_updated"
          show_images={[]}
          added?={true}
        >
          <p class="my-2 font-serif text-dark-sage">
            Explore the latest additions to our growing collection of South Asian ephemera.
          </p>
        </.browse_item_row>

        <!-- Browse All Section -->
        <div class="bg-dark-sage text-light-text py-12">
          <div class="content-area text-center">
            <h2 class="text-3xl font-bold mb-4">Ready to Explore?</h2>
            <p class="text-xl mb-8 font-serif">
              Dive deep into thousands of documents that tell the story of South Asian societies.
            </p>
            <.primary_button 
              href="/search?filter[project]=South+Asian+Ephemera" 
              class="bg-accent hover:bg-rust text-light-text text-lg px-8 py-4"
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
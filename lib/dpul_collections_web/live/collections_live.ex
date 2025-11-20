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
      <div class="flex items-center gap-3 mb-2 mt-4">
        <h2 id={"#{@container_id}-header"} class="text-sm font-sans font-medium">
          {@title}
        </h2>
      </div>
      <div
        phx-hook="ResponsivePills"
        id={@container_id}
      >
        <ul
          aria-labelledby={"#{@container_id}-header"}
          class="group max-h-[2.5rem] [&.expanded]:max-h-none flex flex-wrap gap-2 overflow-hidden"
        >
          <%= for {{value, count}, idx} <- Enum.with_index(@items) do %>
            <li
              aria-setsize={length(@items) + 2}
              aria-posinset={idx + 1}
              class="pill-item group-[.expanded]:block"
            >
              <.filter_link_button
                filter_name={@unit}
                filter_value={value}
                collection_filter={@collection_title}
                class={@pill_class}
              >
                {value} ({count})
              </.filter_link_button>
            </li>
          <% end %>
          <li class={"hidden group-[.expanded]:block less-button #{@button_class}"}>
            <button class="w-full h-full px-3 py-1.5 cursor-pointer text-xs">
              Show less
            </button>
          </li>
          <li class={"more-button invisible group-[.expanded]:invisible less-button px-3 py-1.5 #{@button_class}"}>
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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="collection-page"
        class="grid grid-flow-row auto-rows-max -mb-6 [&>*:nth-child(odd)]:bg-background [&>*:nth-child(even)]:bg-dark-gray [&>*:nth-child(even)]:text-light-text"
      >
        <!-- Hero Section -->
        <div class="content-area relative overflow-hidden">
          <div class="left-[15%] absolute z-10">
            <img src="/images/triangle-mosaic.png" alt="" class="mx-auto w-xl" />
          </div>
          <div class="space-y-2 relative z-30">
            <p class="text-accent font-semibold text-xl uppercase tracking-wide">
              {gettext("Digital Collection")}
            </p>
            <h1 class="flex-grow-1 text-4xl lg:text-6xl font-[1000]">
              {@collection.title |> hd}
            </h1>
          </div>
          <div class="page-y-padding relative z-30">
            <div class="hero-container-collection grid grid-cols-1 md:grid-cols-2 gap-0 md:grid-cols-[auto_60%]">
              <!-- Right Column: Featured Items Mosaic -->
              <div id="collection-mosaic" class="image-col self-start h-120">
                <div class="w-full h-full relative">
                  <.primary_button
                    href={~p"/search?#{%{filter: %{project: [@collection.title |> hd]}}}"}
                    class="btn-primary absolute bottom-[-.5rem] right-0 hidden md:flex"
                  >
                    {gettext("Browse Collection")}
                  </.primary_button>
                  <%= for {item, index} <-  Enum.with_index(@collection.featured_items) do %>
                    <.link
                      href={item.url}
                      class={"card-darkdrop w-[100%] p-2 bg-white min-h-0 min-w-0 absolute z-[#{index}] drop-shadow-none"}
                      aria-label={"View #{item.title |> hd}"}
                    >
                      <div class="max-h-75 md:max-h-100 h-full w-full overflow-hidden">
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
              
    <!-- Left Column: Content -->
              <div class="tagline-col">
                <div class="w-full relative z-30">
                  <div class="w-full h-full bg-white opacity-75 absolute z-40"></div>
                  <div class="flex flex-wrap gap-4 p-5 relative z-50 -mt-[10rem] md:mt-0">
                    <p class="text-lg text-dark-text pb-2">
                      {@collection.tagline}
                    </p>
                    <div class="flex flex-wrap justify-center items-center text-dark-text gap-2">
                      <div class="text-sm bg-cloud rounded-full px-3 py-1">
                        {@collection.item_count} {gettext("Items")}
                      </div>
                      <div class="text-sm bg-cloud rounded-full px-3 py-1">
                        {length(@collection.languages)} {gettext("Languages")}
                      </div>
                      <div class="text-sm bg-cloud rounded-full px-3 py-1">
                        {length(@collection.geographic_origins)} {gettext("Locations")}
                      </div>
                    </div>
                  </div>
                </div>
                <div class="flex flex-wrap gap-4 py-4">
                  <a
                    href="#learn-more"
                    class="btn-secondary grow md:grow-0"
                  >
                    {gettext("Learn More")}
                  </a>
                </div>
              </div>
              <div class="grid-cols-1 col-span-2 static md:hidden">
                <.primary_button
                  href={~p"/search?#{%{filter: %{project: [@collection.title |> hd]}}}"}
                  class="btn-primary w-full"
                >
                  {gettext("Browse Collection")}
                </.primary_button>
              </div>
            </div>
          </div>
        </div>
        <div
          :if={length(@collection.featured_items) > 0}
          id="featured-items-container"
          phx-update="ignore"
          class="grid-flow auto-rows-max"
        >
          <.content_separator />
          <.browse_item_row
            id="featured-items"
            layout="content-area"
            items={@collection.featured_items}
            title={gettext("Featured Highlights")}
            show_images={[]}
            current_path={@current_path}
            current_scope={@current_scope}
            color=""
          >
          </.browse_item_row>
        </div>
        <!-- Learn More -->
        <div id="learn-more" class="grid-flow-row text-dark-text auto-rows-max">
          <.content_separator />
          <div class="content-area">
            <h2 class="uppercase font-semibold text-4xl py-6">
              {gettext("Learn More")}
            </h2>
          </div>
          <div
            id="collection-description"
            class="content-area grid grid-cols-1 gap-6"
          >
            <div>
              <.pill_section
                title={gettext("Subject Areas")}
                unit="category"
                items={@collection.categories}
                container_id="categories-container"
                pill_class="btn-primary-bright-colors"
                button_class="bg-primary-bright/80 hover:bg-primary-bright/60"
                collection_title={@collection.title |> hd}
              />

              <.pill_section
                title={gettext("Genres")}
                unit="genre"
                items={@collection.genres}
                container_id="genres-container"
                pill_class="btn-secondary-colors"
                button_class="bg-cloud/80 hover:bg-cloud/60"
                collection_title={@collection.title |> hd}
              />
            </div>
            <div class="[&_a]:text-accent w-full text-lg page-t-padding">
              <div class="collection-description leading-relaxed pb-6">
                {@collection.description |> raw}
              </div>
            </div>
          </div>
        </div>
        <!-- Recently Updated Items -->
        <div :if={length(@collection.recently_added) > 0}>
          <.content_separator />
          <.browse_item_row
            id="recent-items"
            layout="content-area"
            items={@collection.recently_added}
            title={gettext("Recently Added Items")}
            more_link={
              ~p"/search?#{%{filter: %{project: [@collection.title |> hd]}, sort_by: "recently_added"}}"
            }
            show_images={[]}
            added?={true}
            current_path={@current_path}
            color=""
          >
            <p class="my-2 text-inherit">
              {gettext("Explore the latest additions to our growing collection for")} {@collection.title
              |> hd}.
            </p>
          </.browse_item_row>
        </div>
        <!-- Contributors -->
        <div
          class="w-full page-y-padding page-x-padding flex flex-col"
          id="contributors"
        >
          <div
            :if={length(@collection.contributors) > 0}
            id="contributors"
            class="content-area pb-6"
          >
            <h2 class="heading text-2xl pb-4">Contributors</h2>
            <div class="flex flex-wrap gap-4 pb-6">
              <div
                :for={contributor <- @collection.contributors}
                class="contributor-card item card-nodrop flex basis-full first:grow lg:basis-[calc(50%-0.5rem)]"
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
                        class=""
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
            <hr />
          </div>
          <div id="policies" class="content-area pb-6">
            <h3 class="uppercase font-semibold text-xl pt-6">
              {gettext("Copyright")}
            </h3>
            <p>
              {gettext(
                "Princeton University Library claims no copyright governing this digital resource.
              It is provided for free, on a non-commercial, open-access basis, for fair-use academic
              and research purposes only. Anyone who claims copyright over any part of these resources
              and feels that they should not be presented in this manner is invited to"
              )}
              <a href="https://library.princeton.edu/form/removal-request">
              {gettext("contact Princeton University Library")}
              </a>, {gettext(
                "who will in turn consider such concerns and make reasonable efforts to respond to such concerns"
              )}.
            </p>
            <h3 class="uppercase font-semibold text-xl pt-6">
              {gettext("Preferred Citation")}
            </h3>
            <p>
              [Identification of item], [Sub-collection name (if applicable)], {@collection.title
              |> hd} Collection, Princeton University Library.
            </p>
            <h3 class="uppercase font-semibold text-xl pt-6">
              {gettext("Romanization")}
            </h3>
            <p>
              {gettext("Please refer to the")}
              <a href="https://www.loc.gov/catdir/cpso/roman.html">
                {gettext("Library of Congress Romanization tables")}
              </a>
              {gettext("when searching the collection")}.
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

defmodule DpulCollectionsWeb.CollectionsLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.Collection

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    collection =
      Collection.from_slug(slug)
      |> Collection.load_related_records()

    case collection do
      nil ->
        raise DpulCollectionsWeb.CollectionsLive.NotFoundError

      _ ->
        socket =
          assign(socket,
            page_title: collection.title,
            collection: collection,
            banner_item: collection.banner_item
          )

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      collection_title={@collection.title |> hd}
    >
      <div
        id="collection-page"
        class="grid grid-flow-row auto-rows-max -mb-6 [&>*:nth-child(odd)]:bg-background [&>*:nth-child(even)]:bg-neutral-600 [&>*:nth-child(even)]:text-light-text"
      >
        <.collection_hero collection={@collection} banner_item={@banner_item} />
        <.featured_and_related
          :if={length(@collection.featured_items) > 0 || length(@collection.related_collections) > 0}
          collection={@collection}
          current_scope={@current_scope}
          current_path={@current_path}
        />
        <.learn_more collection={@collection} />
        <.recently_updated
          :if={length(@collection.recently_added) > 0}
          collection={@collection}
          current_path={@current_path}
        />
        <.contributors_and_policies collection={@collection} />
      </div>
    </Layouts.app>
    """
  end

  def collection_hero(assigns) do
    ~H"""
    <div class="content-area relative">
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
        <div class="hero-container-collection flex md:flex-row-reverse flex-col gap-0">
          <!-- Right Column: Featured Items Banner -->
          <div
            id="collection-banner"
            class="flex flex-col gap-4 w-full grow"
            phx-update="ignore"
          >
            <.banner_image collection={@collection} banner_item={@banner_item} />
            <div class="flex justify-items-end">
              <.primary_button
                href={~p"/search?#{%{filter: %{collection: [@collection.title |> hd]}}}"}
                class="btn-primary hidden md:flex ml-auto"
              >
                {gettext("Browse Collection")}
              </.primary_button>
            </div>
          </div>
          <!-- Left Column: Content -->
          <div class="md:max-w-[40%]">
            <div class="w-full relative z-30">
              <div class="flex flex-wrap gap-4 p-5 relative z-50 bg-white/75">
                <p class="text-lg text-dark-text pb-2">
                  {@collection.tagline}
                </p>
                <div class="flex flex-wrap justify-center items-center text-dark-text gap-2">
                  <div class="text-sm bg-cloud rounded-full px-3 py-1">
                    {format_number(@collection.item_count)} {gettext("Items")}
                  </div>
                  <div
                    :if={length(@collection.languages) > 0}
                    class="text-sm bg-cloud rounded-full px-3 py-1"
                  >
                    {format_number(length(@collection.languages))} {gettext("Languages")}
                  </div>
                  <div
                    :if={length(@collection.geographic_origins) > 0}
                    class="text-sm bg-cloud rounded-full px-3 py-1"
                  >
                    {format_number(length(@collection.geographic_origins))} {gettext("Locations")}
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
              href={~p"/search?#{%{filter: %{collection: [@collection.title |> hd]}}}"}
              class="btn-primary w-full"
            >
              {gettext("Browse Collection")}
            </.primary_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def featured_and_related(assigns) do
    ~H"""
    <div>
      <.content_separator />
      <div
        :if={length(@collection.featured_items) > 0}
        id="featured-items-container"
        phx-update="ignore"
        class="grid-flow auto-rows-max"
      >
        <.card_row
          id="featured-items"
          layout="content-area"
          title={gettext("Featured Highlights")}
          color=""
          arrow_theme="light"
        >
          <.item_browse_card_li
            :for={item <- @collection.featured_items}
            show_images={[]}
            item={item}
            current_scope={@current_scope}
            current_path={@current_path}
          />
        </.card_row>
      </div>
      <div
        :if={length(@collection.related_collections) > 0}
        id="related-collections-container"
        phx-update="ignore"
        class="grid-flow auto-rows-max"
      >
        <.card_row
          id="related-collections"
          layout="content-area"
          title={gettext("Related Collections")}
          color=""
          arrow_theme="light"
        >
          <.collection_card_li
            :for={item <- @collection.related_collections}
            collection={item}
          />
        </.card_row>
      </div>
    </div>
    """
  end

  def learn_more(assigns) do
    ~H"""
    <div id="learn-more" class="grid-flow-row text-dark-text auto-rows-max page-b-padding">
      <.content_separator />
      <div class="content-area">
        <h2 class="uppercase font-semibold text-4xl py-6">
          {gettext("Learn More")}
        </h2>
      </div>
      <div
        id="collection-summary"
        class="content-area grid grid-cols-1 md:grid-cols-3 items-baseline gap-6 font-serif"
      >
        <div class="[&_a]:text-accent text-lg row-2 md:col-span-2">
          <div class="collection-summary pb-6 flex flex-col gap-4 [&_h3]:heading [&_h3]:text-md">
            {@collection.summary |> raw}
          </div>
        </div>
        <div class="flex flex-col gap-6 row-1 md:row-2">
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
            title={gettext("Formats")}
            unit="format"
            items={@collection.formats}
            container_id="formats-container"
            pill_class="btn-secondary-colors"
            button_class="bg-cloud/80 hover:bg-cloud/60"
            collection_title={@collection.title |> hd}
          />
          <.pill_section
            title={gettext("Languages")}
            unit="language"
            items={@collection.languages}
            container_id="languages-container"
            pill_class="btn-primary-bright-colors"
            button_class="bg-primary-bright/80 hover:bg-primary-bright/60"
            collection_title={@collection.title |> hd}
          />
        </div>
      </div>
    </div>
    """
  end

  def recently_updated(assigns) do
    ~H"""
    <div>
      <.content_separator />
      <.card_row
        id="recent-items"
        layout="content-area"
        title={gettext("Recently Added Items")}
        more_link={
          ~p"/search?#{%{filter: %{collection: [@collection.title |> hd]}, sort_by: "recently_added"}}"
        }
        color=""
        arrow_theme="light"
      >
        <:intro>
          <p class="my-2">
            {gettext("Explore the latest additions to")} {@collection.title |> hd}.
          </p>
        </:intro>
        <.item_browse_card_li
          :for={item <- @collection.recently_added}
          show_images={[]}
          item={item}
          added?={true}
          current_path={@current_path}
        />
      </.card_row>
    </div>
    """
  end

  def contributors_and_policies(assigns) do
    ~H"""
    <div
      class="w-full page-y-padding page-x-padding flex flex-col"
      id="contributors"
    >
      <div
        :if={length(@collection.contributors) > 0}
        id="contributors"
        class="content-area pb-6"
      >
        <h2 class="heading text-2xl pb-4">{gettext("Contributors")}</h2>
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
                <div class="w-full flex items-center overflow-hidden justify-center gap-2 max-h-[150px] p-2">
                  <img
                    src={contributor.logo}
                    class="object-contain max-w-full max-h-full"
                    alt=""
                  />
                </div>
              </div>
              <div class="metadata sm:col-span-5 flex flex-col gap-2 sm:gap-4 p-4">
                <div class="flex flex-wrap flex-row sm:flex-row justify-between">
                  <.link
                    href={contributor.url}
                    target="_blank"
                    class="underline hover:border-none hover:no-underline"
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
          {raw(
            gettext(
              "Princeton University Library claims no copyright governing this digital resource. It is provided for free, on a non-commercial, open-access basis, for fair-use academic and research purposes only. Anyone who claims copyright over any part of these resources and feels that they should not be presented in this manner is invited to %{contact_link}, who will in turn consider such concerns and make reasonable efforts to respond to such concerns.",
              contact_link:
                "<a href=\"https://library.princeton.edu/form/removal-request\">#{gettext("contact Princeton University Library")}</a>"
            )
          )}
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
          {raw(
            gettext(
              "Please refer to the %{romanization_link} when searching the collection.",
              romanization_link:
                "<a href=\"https://www.loc.gov/catdir/cpso/roman.html\">#{gettext("Library of Congress Romanization tables")}</a>"
            )
          )}
        </p>
      </div>
    </div>
    """
  end

  defp pill_section(assigns) do
    ~H"""
    <div :if={length(@items) > 0} class="flex flex-col gap-4">
      <div class="flex items-center gap-3">
        <h2 id={"#{@container_id}-header"} class="heading text-sm text-end">
          {@title}
        </h2>
      </div>
      <div
        phx-hook="ResponsivePills"
        id={@container_id}
      >
        <ul
          aria-labelledby={"#{@container_id}-header"}
          class="group flex flex-wrap gap-2"
        >
          <%= for {{value, count}, idx} <- Enum.with_index(@items) do %>
            <li
              aria-setsize={length(@items) + 2}
              aria-posinset={idx + 1}
              class="h-10 pill-item group-[.expanded]:block"
            >
              <.filter_link_button
                filter_name={@unit}
                filter_value={value}
                collection_filter={@collection_title}
                class={@pill_class}
              >
                {value} ({format_number(count)})
              </.filter_link_button>
            </li>
          <% end %>
          <li class={"hidden group-[.expanded]:block less-button #{@button_class}"}>
            <button class="w-full h-full px-3 py-1.5 cursor-pointer text-xs">
              {gettext("Show less")}
            </button>
          </li>
          <li class={"more-button invisible group-[.expanded]:invisible less-button px-3 py-1.5 #{@button_class}"}>
            <button class="w-full h-full cursor-pointer text-xs">
              +<span class="more-count">{format_number(length(@items))}</span> {gettext("more")}
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def banner_image(
        assigns = %{collection: %{banner_image: banner_image, banner_image_id: banner_image_id}}
      )
      when is_binary(banner_image) and is_binary(banner_image_id) do
    ~H"""
    <div class="max-h-120 p-2 bg-white min-h-0 min-w-0 flex">
      <div class="overflow-hidden w-full">
        <.link
          :if={@banner_item}
          href={@banner_item.url}
          class="overflow-hidden"
          aria-label={"View #{@banner_item.title |> hd}"}
        >
          <img
            src={Collection.banner_source(@collection)}
            width="750"
            height="500"
            class="object-cover object-top max-h-full max-w-full w-full"
            alt=""
          />
        </.link>
      </div>
    </div>
    """
  end

  def banner_image(assigns) do
    ~H"""
    <div class="max-h-120 p-2 card-darkdrop bg-white min-h-0 min-w-0 flex">
      <div class="overflow-hidden w-full">
        <.link
          :if={@banner_item}
          href={@banner_item.url}
          class="overflow-hidden"
          aria-label={"View #{@banner_item.title |> hd}"}
        >
          <img
            src={Collection.banner_source(@collection)}
            width={@banner_item.primary_thumbnail_width}
            height={@banner_item.primary_thumbnail_height}
            class="object-cover object-top max-h-full max-w-full w-full"
            alt=""
          />
        </.link>
      </div>
    </div>
    """
  end
end

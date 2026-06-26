defmodule DpulCollectionsWeb.SearchItem do
  alias DpulCollections.Collection
  alias DpulCollections.Item
  alias DpulCollectionsWeb.Live.Helpers
  alias DpulCollectionsWeb.UserSets
  alias DpulCollectionsWeb.ContentWarnings
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def search_item(assigns = %{item: %Collection{}}) do
    ~H"""
    <li
      id={"item-#{@item.id}"}
      class="item card"
      data-id={@item.id}
      aria-label={@item.title |> hd}
    >
      <div class="grid-rows-2 bg-sage-100 grid sm:grid-rows-1 sm:grid-cols-4 gap-0">
        <div class={[
          "search-thumbnail",
          "row-span-2 col-span-1",
          "bg-search flex justify-center relative",
          "h-full"
        ]}>
          <div class="grid grid-cols-2 w-full gap-2 h-[350px] p-2">
            <img
              :for={item <- @item.banner_items}
              src={"#{item.primary_thumbnail_service_url}/full/!#{item.primary_thumbnail_width},#{item.primary_thumbnail_height}/0/default.jpg"}
              width={item.primary_thumbnail_width}
              height={item.primary_thumbnail_height}
              class="min-h-0 min-w-0 object-cover object-top h-full w-full max-h-full"
              alt={item.title |> hd}
            />
          </div>
        </div>
        <div
          class="metadata sm:col-span-3 flex flex-col gap-2 sm:gap-4 p-4"
          id={"item-metadata-#{@item.id}"}
        >
          <div class="flex flex-wrap sm:flex-nowrap flex-row justify-between">
            <h2 dir="auto" class="w-full flex-grow sm:w-auto sm:min-w-0">
              <.link
                navigate={@item.url}
                class="card-link"
              >
                {@item.title}
              </.link>
            </h2>
            <span
              aria-label={gettext("format")}
              data-field="format"
              class="w-full sm:w-fit flex-grow sm:flex-none text-gray-600 font-bold text-base uppercase sm:text-right"
            >
              {@item.format}
            </span>
          </div>
          <div :if={@item.tagline} class="text-base">{@item.tagline}</div>
          <div class="brief-metadata flex flex-auto flex-row gap-4">
            <div class="flex flex-col pe-4 gap-0 py-0 h-min">
              <div class="text-lg">{format_number(@item.item_count)}</div>
              <div class="text-base">Items</div>
            </div>
            <div class="flex flex-col pe-4 gap-0 py-0 h-min">
              <div class="text-lg">{format_number(length(@item.languages))}</div>
              <div class="text-base">Languages</div>
            </div>
            <div class="flex flex-col pe-4 gap-0 py-0 h-min">
              <div class="text-lg">{format_number(length(@item.geographic_origins))}</div>
              <div class="text-base">Locations</div>
            </div>
          </div>
        </div>
      </div>
    </li>
    """
  end

  def search_item(assigns = %{item: %Item{}}) do
    ~H"""
    <li
      id={"item-#{@item.id}"}
      class="item card text-start"
      aria-label={@item.title |> hd}
      phx-hook="ShowPageCount"
      data-id={@item.id}
      data-filecount={@item.file_count}
    >
      <div
        :if={Helpers.obfuscate_item?(assigns)}
        class="h-[2.5rem]"
      >
        <ContentWarnings.show_images_banner
          item_id={@item.id}
          content_warning={@item.content_warning}
        />
      </div>
      <div class="grid-rows-2 bg-sage-100 grid sm:grid-rows-1 sm:grid-cols-4 gap-0">
        <div
          :if={@item.file_count && length(@item.image_service_urls) > 0}
          class="row-span-2 col-span-1 relative"
        >
          <.large_thumb
            thumb={elem(hd(thumbnail_service_urls(0, 1, @item)), 0)}
            thumb_num={0}
            item={@item}
            show_images={@show_images}
          />
          <%!-- Mobile-only --%>
          <div class="absolute right-0 top-0 p-2 z-10 sm:hidden">
            <UserSets.AddToSetComponent.add_button
              current_scope={@current_scope}
              item_id={@item.id}
              current_path={@current_path}
            />
          </div>
        </div>
        <div
          class="metadata sm:col-span-3 sm:col-start-2 flex flex-col gap-2 sm:gap-4 p-4"
          id={"item-metadata-#{@item.id}"}
        >
          <div class="flex flex-col sm:flex-row gap-2 sm:gap-4">
            <div class="flex flex-col gap-2 sm:gap-4 grow min-w-0">
              <h2 dir="auto" class="w-full min-w-0">
                <.link
                  navigate={@item.url}
                  class="card-link"
                  id={"item-title-#{@item.id}"}
                >
                  {@item.title}
                </.link>
              </h2>
              <div
                :if={
                  !Enum.empty?(@item.transliterated_title) || !Enum.empty?(@item.alternative_title)
                }
                id={"item-translit-title-#{@item.id}"}
                class="mt-[-1rem] flex flex-col gap-1"
              >
                <h3
                  :for={ttitle <- @item.transliterated_title}
                  dir="auto"
                  class="font-medium text-gray-600"
                >
                  {ttitle}
                </h3>
              </div>
              <div :if={@sort_by == :recently_added && @item.updated_at} class="updated-at w-full">
                {gettext("Added")} {DpulCollectionsWeb.BrowseItem.time_ago(@item.updated_at)}
              </div>
              <.search_brief_metadata item={@item} />
            </div>
            <div class="flex flex-col gap-2 sm:gap-4 shrink-0 order-first sm:order-none sm:items-end">
              <span
                aria-label={gettext("format")}
                data-field="format"
                class="w-full sm:w-auto text-gray-600 font-bold text-base uppercase sm:text-right"
              >
                {@item.format}
              </span>
              <div class="hidden sm:flex">
                <UserSets.AddToSetComponent.add_button
                  current_scope={@current_scope}
                  item_id={@item.id}
                  current_path={@current_path}
                />
              </div>
            </div>
          </div>
          <div class="small-thumbnails hidden sm:flex flex-row flex-wrap gap-5 max-h-[125px] justify-start overflow-hidden">
            <.thumbs
              :for={{thumb, thumb_num} <- thumbnail_service_urls(1, 6, @item)}
              :if={@item.file_count > 1}
              thumb={thumb}
              thumb_num={thumb_num + 1}
              item={@item}
              show_images={@show_images}
            />
            <div
              id={"filecount-#{@item.id}"}
              class="hidden absolute diagonal-rise -right-px -bottom-px bg-sage-100 pr-4 py-2 text-sm"
            >
              {format_number(@item.file_count)} {gettext("Files")}
            </div>
          </div>
        </div>
      </div>
    </li>
    """
  end

  def large_thumb(assigns) do
    ~H"""
    <div class={[
      "search-thumbnail",
      "row-span-2 col-span-1",
      "grid grid-cols-1 auto-rows-auto gap-2",
      "bg-search flex justify-center relative p-2",
      "h-full"
    ]}>
      <img
        class={[
          "primary-thumbnail",
          "h-[350px] w-[350px]",
          "sm:h-[225px] sm:w-[225px]",
          "bg-search object-contain",
          Helpers.obfuscate_item?(assigns) && "obfuscate",
          "thumbnail-#{@item.id}",
          "place-self-center"
        ]}
        src={"#{@thumb}/full/!350,350/0/default.jpg"}
        alt=""
      />
      <div class={[
        "small-thumbnails sm:hidden",
        "grid grid-template-rows-[auto]",
        "grid-cols-[repeat(auto-fill,minmax(80px,1fr))]",
        "max-h-[80px] overflow-hidden gap-1",
        @item.file_count > 5 && "justify-evenly",
        @item.file_count <= 5 && "justify-start"
      ]}>
        <.thumbs
          :for={{thumb, thumb_num} <- thumbnail_service_urls(1, 6, @item)}
          :if={@item.file_count > 1}
          thumb={thumb}
          thumb_num={thumb_num + 1}
          item={@item}
          show_images={@show_images}
        />
      </div>
      <div
        :if={@item.file_count > 1}
        class="absolute sm:hidden diagonal-rise right-0 bottom-0 bg-sage-100 pr-4 py-2"
      >
        {format_number(@item.file_count)} {gettext("Files")}
      </div>
    </div>
    """
  end

  defp thumbnail_service_urls(start, max_thumbnails, item) do
    thumbnail_service_urls(
      start,
      max_thumbnails,
      item.image_service_urls,
      item.primary_thumbnail_service_url
    )
  end

  defp thumbnail_service_urls(start, max_thumbnails, image_service_urls, nil) do
    # Truncate image service urls to max value
    image_service_urls
    |> Enum.slice(start, max_thumbnails)
    |> Enum.with_index()
  end

  defp thumbnail_service_urls(
         start,
         max_thumbnails,
         image_service_urls,
         primary_thumbnail_service_url
       ) do
    # Move thumbnail url to front of list and then truncate to max value
    image_service_urls
    |> Enum.filter(&(&1 != primary_thumbnail_service_url))
    |> List.insert_at(0, primary_thumbnail_service_url)
    |> Enum.slice(start, max_thumbnails)
    |> Enum.with_index()
  end

  defp search_brief_metadata(assigns) do
    ~H"""
    <div class="brief-metadata-wrap">
      <div>
        <div
          :if={length(@item.publisher) > 0}
          class="publisher"
        >
          <div class="text-base text-gray-600">{gettext("Publisher")}</div>
          <div class="text-lg">{@item.publisher |> Enum.at(0)}</div>
        </div>
        <div
          :if={@item.date}
          class="date"
        >
          <div class="text-base text-gray-600">{gettext("Date")}</div>
          <div class="text-lg">{@item.date}</div>
        </div>
        <div
          :if={length(@item.geographic_origin) > 0}
          class="origin"
        >
          <div class="text-base text-gray-600">{gettext("Origin")}</div>
          <div class="text-lg">{@item.geographic_origin}</div>
        </div>
      </div>
    </div>
    """
  end

  def thumbs(assigns) do
    ~H"""
    <div class="relative sm:w-[125px] flex justify-center">
      <img
        class={[
          "h-[80px] w-[80px] sm:h-[125px] sm:w-[125px] border border-solid border-gray-400",
          "object-cover",
          Helpers.obfuscate_item?(assigns) && "obfuscate",
          "thumbnail-#{@item.id}"
        ]}
        src={"#{@thumb}/square/!350,350/0/default.jpg"}
        alt=""
        style="background-color: lightgray;"
        width="125"
        height="125"
      />
    </div>
    """
  end
end

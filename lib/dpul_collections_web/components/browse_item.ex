defmodule DpulCollectionsWeb.BrowseItem do
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.Item
  alias DpulCollectionsWeb.Live.Helpers
  alias DpulCollectionsWeb.ContentWarnings

  attr :items, :list, required: true
  attr :title, :string, required: true
  attr :added?, :boolean, default: false
  attr :more_link, :string, default: nil
  attr :color, :string, default: "bg-secondary"
  attr :layout, :string, default: "content-area"
  attr :rest, :global

  attr :show_images, :list,
    default: [],
    doc: "the list of images stored in session that should not be obfuscated"

  slot :inner_block, doc: "the optional inner block that renders above the images"

  def browse_item_row(assigns) do
    ~H"""
    <div class={["grid-row", @color]} {@rest}>
      <div class={@layout}>
        <div class="page-t-padding" />
        <h1>{@title}</h1>
        {render_slot(@inner_block)}
        <div class="flex gap-8 justify-stretch page-t-padding">
          <!-- cards -->
          <div class="w-full recent-container">
            <.browse_item
              :for={item <- @items}
              show_images={@show_images}
              item={item}
              added?={@added?}
              likeable?={false}
            />
          </div>
          <div :if={@more_link} class="w-16 flex-none content-center">
            <.transparent_button
              class="w-16 h-16"
              aria_label={gettext("more items")}
              navigate={@more_link}
            >
              <div class="btn-arrow h-12 w-12"></div>
            </.transparent_button>
          </div>
        </div>
        <div class="page-b-padding" />
      </div>
    </div>
    """
  end

  attr :item, Item, required: true
  attr :added?, :boolean, default: false
  attr :likeable?, :boolean, default: true
  attr :id, :string, required: false, default: "browse-item"
  attr :target, :string, required: false, default: nil
  attr :class, :string, required: false, default: nil

  attr :show_images, :list,
    default: [],
    doc: "the list of images stored in session that should not be obfuscated"

  def browse_item(assigns) do
    ~H"""
    <article
      id={"#{@id}-#{@item.id}"}
      data-item-id={@item.id}
      class={[
        "browse-item overflow-hidden -outline-offset-2 relative card flex bg-white flex-col min-w-[250px]",
        @class
      ]}
    >
      <!-- similar -->
      <div
        :if={@likeable? || Helpers.obfuscate_item?(assigns)}
        class="browse-header mb-2 h-12 w-full bg-white absolute flex items-center"
      >
        <div class="h-full pl-2 w-full flex items-center flex-grow like-header bg-white z-50">
          <ContentWarnings.show_images_banner
            :if={Helpers.obfuscate_item?(assigns)}
            item_id={@item.id}
            content_warning={@item.content_warning}
          />
          <.link
            :if={@likeable?}
            class="flex-grow text-accent font-semibold"
            patch={~p"/browse/focus/#{@item.id}"}
            phx-click={JS.dispatch("dpulc:scrollTop")}
          >
            {gettext("Browse Similar Items")}
          </.link>
        </div>
      </div>
      <.link
        href={@item.url}
        target={@target}
        class="-outline-offset-1 flex-grow item-link flex flex-col"
        aria-label={"View #{@item.title |> hd}"}
      >
        <!-- thumbs -->
        <div class="px-2 pt-2 bg-white">
          <div class="grid grid-rows-[repeat(4, 25%)] gap-2 h-[24rem]">
            <!-- main thumbnail -->
            <div :if={@item.file_count == 1} class="row-span-4">
              <.thumb
                thumb={thumbnail_service_url(@item)}
                href={@item.url}
                item={@item}
                show_images={@show_images}
              />
            </div>

            <div :if={@item.file_count > 1} class="row-span-3 overflow-hidden h-[18rem]">
              <.thumb
                thumb={thumbnail_service_url(@item)}
                href={@item.url}
                item={@item}
                show_images={@show_images}
              />
            </div>
            
    <!-- smaller thumbnails -->
            <div :if={@item.file_count > 1} class="grid grid-cols-4 gap-2 h-[6rem]">
              <.thumb
                :for={{thumb, thumb_num} <- thumbnail_service_urls(4, @item.image_service_urls)}
                :if={@item.file_count}
                thumb={thumb}
                thumb_num={thumb_num}
                href={@item.url}
                item={@item}
                show_images={@show_images}
              />
            </div>
          </div>
        </div>
        <!-- card text area -->
        <div class="relative mx-1 px-6 py-5 bg-white flex flex-col">
          <div
            :if={@item.file_count > 4}
            class="absolute bg-background right-2 top-0 z-10 pr-2 pb-1 diagonal-drop"
          >
            {@item.file_count} {gettext("Images")}
          </div>

          <h2 class="font-normal tracking-tight py-2 flex-grow" dir="auto">
            {truncate_title(@item.title |> hd)}
          </h2>
          <p class="text-gray-700 text-base">{@item.date}</p>
        </div>
        <!-- Footer area -->
        <div class="flex-grow flex w-full flex-col justify-end">
          <div
            :if={@added? && @item.updated_at}
            class="updated-at align-self-end justify-self-end-safe w-full bg-light-secondary h-10 p-2 text-right"
          >
            {"#{gettext("Updated")} #{time_ago(@item.updated_at)}"}
          </div>
        </div>
        <!-- "added on" note -->
      </.link>
    </article>
    """
  end

  defp truncate_title(title, length \\ 70) do
    if String.length(title) > length do
      (title |> String.slice(0, length) |> String.trim_trailing()) <> "..."
    else
      title
    end
  end

  attr :thumb, :string, required: false
  attr :thumb_num, :string, required: false
  attr :item, :map, required: false
  attr :href, :string, required: false, default: nil

  attr :show_images, :list,
    default: [],
    doc: "the list of images stored in session that should not be obfuscated"

  def thumb(assigns) do
    ~H"""
    <img
      class={[
        "thumbnail bg-slate-400 text-white h-full w-full object-cover",
        Helpers.obfuscate_item?(assigns) && "obfuscate",
        "thumbnail-#{@item.id}"
      ]}
      src={thumbnail_url(assigns)}
      alt="thumbnail image"
    />
    """
  end

  def thumbnail_service_urls(max_thumbnails, image_service_urls) do
    # Truncate image service urls to max value
    image_service_urls
    |> Enum.slice(1, max_thumbnails)
    |> Enum.with_index()
  end

  def thumbnail_url(%{thumb: thumb, thumb_num: thumb_num}) when is_number(thumb_num) do
    "#{thumb}/square/100,100/0/default.jpg"
  end

  def thumbnail_url(%{thumb: thumb}) do
    "#{thumb}/square/350,350/0/default.jpg"
  end

  def thumbnail_service_url(%{primary_thumbnail_service_url: thumbnail_url})
      when is_binary(thumbnail_url) do
    thumbnail_url
  end

  def thumbnail_service_url(%{image_service_urls: [url | _]}) do
    url
  end

  # TODO: default image?
  def thumbnail_service_url(_), do: ""

  def time_ago(updated_at) do
    {:ok, dt, _} = DateTime.from_iso8601(updated_at)

    {:ok, str} =
      Cldr.DateTime.Relative.to_string(
        dt,
        DpulCollectionsWeb.Cldr,
        relative_to: DateTime.now!("Etc/UTC"),
        locale: Gettext.get_locale(DpulCollectionsWeb.Gettext)
      )

    str
  end
end

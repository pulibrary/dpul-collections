defmodule DpulCollectionsWeb.BrowseItem do
  use DpulCollectionsWeb, :html
  use Phoenix.Component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.Item

  attr :items, :list, required: true
  attr :title, :string, required: true
  attr :added?, :boolean, default: false
  attr :more_link, :boolean, default: nil
  attr :rest, :global, default: %{class: "grid-row bg-secondary"}
  slot :inner_block, doc: "the optional inner block that renders above the images"

  def browse_item_row(assigns) do
    ~H"""
    <div {@rest}>
      <div class="content-area">
        <div class="page-t-padding" />
        <h1>{@title}</h1>
        {render_slot(@inner_block)}
        <div class="flex gap-8 justify-stretch page-t-padding">
          <!-- cards -->
          <div class="w-full recent-container">
            <.browse_item :for={item <- @items} item={item} added?={@added?} likeable?={false} />
          </div>
          <div :if={@more_link} class="w-12 flex-none content-center">
            <.link
              class="btn-arrow w-full h-14 w-full block"
              aria-label="more items"
              navigate={@more_link}
            >
            </.link>
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

  def browse_item(assigns) do
    ~H"""
    <div
      id={"browse-item-#{@item.id}"}
      class="flex bg-white flex-col overflow-hidden drop-shadow-[0.5rem_0.5rem_0.5rem_var(--color-sage-300)] min-w-[250px]"
    >
      <!-- like -->
      <div
        :if={@likeable?}
        id={"like-#{@item.id}"}
        phx-click={
          JS.push("like")
          |> JS.toggle_class("hidden", to: {:inner, ".icon"})
        }
        phx-value-item_id={@item.id}
        class="h-10 w-10 absolute left-2 top-2 cursor-pointer bg-white text-accent"
      >
        <.icon name="hero-heart-solid" class="h-10 w-10 bg-accent icon selected hidden" />
        <.icon name="hero-heart" class="h-10 w-10 icon selected" />
      </div>
      
    <!-- thumbs -->
      <div class="px-2 pt-2 bg-white">
        <div class="grid grid-rows-[repeat(4, 25%)] gap-2 h-[24rem]">
          <!-- main thumbnail -->
          <div :if={@item.file_count == 1} class="row-span-4">
            <.thumb thumb={thumbnail_service_url(@item)} link={@item.url} />
          </div>

          <div :if={@item.file_count > 1} class="row-span-3 overflow-hidden h-[18rem]">
            <.thumb thumb={thumbnail_service_url(@item)} link={@item.url} />
          </div>
          
    <!-- smaller thumbnails -->
          <div :if={@item.file_count > 1} class="grid grid-cols-4 gap-2 h-[6rem]">
            <.thumb
              :for={{thumb, thumb_num} <- thumbnail_service_urls(4, @item.image_service_urls)}
              :if={@item.file_count}
              thumb={thumb}
              thumb_num={thumb_num}
              link={@item.url}
            />
          </div>
        </div>
      </div>
      
    <!-- card text area -->
      <div class="flex-1 px-6 py-5 bg-white relative">
        <div
          :if={@item.file_count > 4}
          class="absolute bg-background right-2 top-0 z-10 pr-2 pb-1 diagonal-drop"
        >
          {@item.file_count} {gettext("Images")}
        </div>

        <h2 class="font-normal tracking-tight py-2" dir="auto">
          <.link navigate={@item.url} class="item-link">{@item.title}</.link>
        </h2>
        <p class="text-gray-700 text-base">{@item.date}</p>
      </div>
      
    <!-- "added on" note -->
      <div :if={@added?} class="digitized_at self-end w-full bg-light-secondary h-10 p-2 text-right">
        {"#{gettext("Added")} #{time_ago(@item.digitized_at)}"}
      </div>
    </div>
    """
  end

  def thumb(assigns) do
    ~H"""
    <.link navigate={@link} class="thumb-link">
      <img
        class="thumbnail bg-slate-400 text-white h-full w-full object-cover"
        src={thumbnail_url(assigns)}
        alt="thumbnail image"
      />
    </.link>
    """
  end

  defp thumbnail_service_urls(max_thumbnails, image_service_urls) do
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

  defp thumbnail_service_url(%{primary_thumbnail_service_url: thumbnail_url})
       when is_binary(thumbnail_url) do
    thumbnail_url
  end

  defp thumbnail_service_url(%{image_service_urls: [url | _]}) do
    url
  end

  # TODO: default image?
  defp thumbnail_service_url(_), do: ""

  def time_ago(digitized_at) do
    {:ok, dt, _} = DateTime.from_iso8601(digitized_at)

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

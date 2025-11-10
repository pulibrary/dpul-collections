defmodule DpulCollectionsWeb.BrowseItem do
  alias DpulCollectionsWeb.UserSets
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
  attr :current_scope, :map, required: false, default: nil

  attr :show_images, :list,
    default: [],
    doc: "the list of images stored in session that should not be obfuscated"

  slot :inner_block, doc: "the optional inner block that renders above the images"

  def browse_item_row(assigns) do
    ~H"""
    <div class={["grid-row", @color]} {@rest}>
      <div class={@layout}>
        <div class="page-t-padding" />
        <h2>{@title}</h2>
        {render_slot(@inner_block)}
        <div class="flex gap-8 justify-stretch page-t-padding">
          <!-- cards -->
          <ul class="w-full recent-container">
            <.browse_li
              :for={item <- @items}
              show_images={@show_images}
              item={item}
              added?={@added?}
              likeable?={false}
              current_scope={@current_scope}
            />
          </ul>
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

  attr :target_item, :map, required: true, doc: "id and title of the link target"
  attr :thumb_source, Item, required: true
  attr :id_prefix, :string, required: false, default: "browse-item"
  attr :target, :string, required: false, default: nil
  attr :class, :string, required: false, default: nil
  attr :current_scope, :map, required: false, default: nil
  attr :show_small_thumbs?, :boolean, default: true

  attr :show_images, :list,
    default: [],
    doc: "the list of images stored in session that should not be obfuscated"

  slot :extra_info, required: false
  slot :card_footer, required: false
  slot :card_buttons, required: false

  # make sure to wrap these in a ul
  def card_li(assigns) do
    ~H"""
    <li
      id={"#{@id_prefix}-#{@target_item.id}"}
      data-item-id={@thumb_source.id}
      aria-label={first_title(@target_item)}
      class={[
        "browse-item overflow-hidden -outline-offset-2 relative card flex bg-white flex-col min-w-[250px]",
        @class
      ]}
    >
      <div
        :if={Helpers.obfuscate_item?(%{show_images: @show_images, item: @thumb_source})}
        class="browse-header mb-2 h-12 w-full bg-white absolute flex items-center"
      >
        <div class="h-full pl-2 w-full flex items-center flex-grow like-header bg-white z-50">
          <ContentWarnings.show_images_banner
            :if={Helpers.obfuscate_item?(%{show_images: @show_images, item: @thumb_source})}
            item_id={@thumb_source.id}
            content_warning={@thumb_source.content_warning}
          />
        </div>
      </div>
      <div class="-outline-offset-1 flex-grow flex flex-col">
        <!-- thumbs -->
        <div class="px-2 pt-2 bg-white overflow-clip">
          <div class="flex flex-col gap-2 h-[24rem]">
            <!-- main thumbnail -->
            <div class="min-h-0 grow">
              <.thumb
                thumb={thumbnail_service_url(@thumb_source)}
                item={@thumb_source}
                show_images={@show_images}
              />
            </div>

            <div
              :if={@show_small_thumbs? && @thumb_source.file_count > 1}
              class="grid grid-cols-4 gap-2 h-[6rem]"
            >
              <.thumb
                :for={
                  {thumb, thumb_num} <- thumbnail_service_urls(4, @thumb_source.image_service_urls)
                }
                :if={@thumb_source.file_count}
                thumb={thumb}
                thumb_num={thumb_num}
                item={@thumb_source}
                show_images={@show_images}
              />
            </div>
          </div>
        </div>
        <!-- card text area -->
        <div class="grid grid-cols-1 grow">
          <div class="mx-1 px-6 pb-5 bg-white flex flex-col">
            <h2 class="font-normal tracking-tight py-1 flex-grow" dir="auto">
              <.link
                navigate={!@target && @thumb_source.url}
                href={@target != nil && @thumb_source.url}
                target={@target}
                class="card-link"
              >
                {truncate_title(first_title(@target_item))}
              </.link>
            </h2>
            <div class="brief-metadata pt-4 text-gray-700 text-base">
              {render_slot(@extra_info)}
            </div>
          </div>
          <div class="h-8 relative order-first">
            <div
              :if={@thumb_source.file_count > 4}
              class="absolute bg-background right-2 top-0 z-10 pr-2 pb-1 diagonal-drop"
            >
              {@thumb_source.file_count} {gettext("Files")}
            </div>
          </div>
          <div class="flex-grow flex w-full flex-col justify-end">
            {render_slot(@card_footer)}
          </div>
        </div>
        <div class="absolute p-4 right-0 flex gap-2">
          {render_slot(@card_buttons)}
        </div>
      </div>
    </li>
    """
  end

  attr :item, Item, required: true
  attr :added?, :boolean, default: false
  attr :likeable?, :boolean, default: true
  attr :savable?, :boolean, default: true
  attr :id_prefix, :string, required: false, default: "browse-item"
  attr :target, :string, required: false, default: nil
  attr :class, :string, required: false, default: nil
  attr :current_scope, :map, required: false, default: nil

  attr :show_images, :list,
    default: [],
    doc: "the list of images stored in session that should not be obfuscated"

  # make sure to wrap these in a ul
  def browse_li(assigns) do
    ~H"""
    <.card_li
      target_item={@item}
      thumb_source={@item}
      id_prefix={@id_prefix}
      target={@target}
      class={@class}
      current_scope={@current_scope}
      show_images={@show_images}
    >
      <:extra_info>
        <div
          :if={@item.date}
          class="date"
        >
          <div>{gettext("Date")}</div>
          <div>{@item.date}</div>
        </div>
        <div
          :if={@item.genre}
          class="genre"
        >
          <div>{gettext("Genre")}</div>
          <div>{@item.genre}</div>
        </div>
      </:extra_info>
      <:card_footer>
        <div
          :if={@added? && @item.updated_at}
          class="updated-at w-full bg-light-secondary h-10 p-2 text-right"
        >
          {"#{gettext("Updated")} #{time_ago(@item.updated_at)}"}
        </div>
      </:card_footer>
      <:card_buttons>
        <.card_button
          :if={@likeable?}
          patch={~p"/browse/focus/#{@item.id}"}
          phx-click={JS.dispatch("dpulc:scrollTop")}
          icon="iconoir:binocular"
          label={gettext("Similar")}
        />
        <UserSets.AddToSetComponent.add_button :if={@current_scope && @savable?} item_id={@item.id} />
      </:card_buttons>
    </.card_li>
    """
  end

  defp first_title(%{title: title}) when is_list(title) do
    title |> hd()
  end

  defp first_title(%{title: title}) do
    title
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
      alt=""
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
    "#{thumb}/square/!100,100/0/default.jpg"
  end

  def thumbnail_url(%{thumb: thumb}) do
    "#{thumb}/square/!350,350/0/default.jpg"
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

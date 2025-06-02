defmodule DpulCollectionsWeb.ItemLive do
  alias DpulCollectionsWeb.Live.Helpers
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, uri, socket) do
    item = Solr.find_by_id(id) |> Item.from_solr()
    path = URI.parse(uri).path |> URI.decode()
    {:noreply, build_socket(socket, item, path)}
  end

  defp build_socket(socket, item, path) when item.url != path do
    push_patch(socket, to: item.url, replace: true)
  end

  defp build_socket(_, nil, _) do
    raise DpulCollectionsWeb.ItemLive.NotFoundError
  end

  defp build_socket(socket, item, _) do
    assign(socket, item: item)
  end

  attr :facet_name, :string, required: true
  attr :facet_value, :string, required: true
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the link"

  def facet_link(assigns) do
    ~H"""
    <.link
      href={~p"/search?#{%{facet: %{@facet_name => @facet_value}} |> Helpers.clean_params()}"}
      {@rest}
    >
      {@facet_value}
    </.link>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="content-area item-page">
      <div class="column-layout my-5 flex flex-col sm:grid sm:grid-flow-row sm:auto-rows-0 sm:grid-cols-5 sm:grid-rows-[auto_1fr] sm:content-start gap-x-14 gap-y-4">
        <div class="item-title sm:row-start-1 sm:col-start-3 sm:col-span-3 h-min flex flex-col gap-4">
          <.facet_link
            class="text-xl uppercase tracking-wide"
            facet_value={@item.genre |> List.first()}
            facet_name="genre"
          />
          <h1 class="text-4xl font-bold normal-case">{@item.title}</h1>
          <div
            :if={!Enum.empty?(@item.transliterated_title) || !Enum.empty?(@item.alternative_title)}
            class="flex flex-col gap-2"
          >
            <p :for={ttitle <- @item.transliterated_title} class="text-2xl font-medium text-gray-500">
              {ttitle}
            </p>
            <p :for={atitle <- @item.alternative_title} class="text-2xl font-medium text-gray-500">
              [{atitle}]
            </p>
          </div>
          <p :if={@item.date} class="text-xl font-medium text-dark-text">{@item.date}</p>
        </div>

        <div class="thumbnails w-full sm:row-start-1 sm:col-start-1 sm:col-span-2 sm:row-span-full">
          <.primary_thumbnail item={@item} />

          <.action_bar class="sm:hidden pt-4" item={@item} />

          <section class="page-thumbnails hidden sm:block md:col-span-2 py-4">
            <h2 class="py-1">{gettext("Pages")}</h2>
            <div class="grid grid-cols-2 py-1 pr-2">
              <div class="text-left text-l text-gray-600 font-semibold">
                {gettext("%{file_min} of %{file_max} pages",
                  file_min: min(@item.file_count, 12),
                  file_max: @item.file_count
                )}
              </div>
              <div class="text-right text-accent uppercase">
                <a href="#" target="_blank">
                  {gettext("View all pages")}
                </a>
              </div>
            </div>
            <div class="py-1 grid grid-cols-4">
              <.thumbs
                :for={{thumb, thumb_num} <- Enum.with_index(Enum.take(@item.image_service_urls, 12))}
                :if={@item.file_count}
                thumb={thumb}
                thumb_num={thumb_num}
              />
            </div>
          </section>
        </div>

        <div class="metadata sm:row-start-2 sm:col-span-3 sm:col-start-3 flex flex-col gap-8">
          <div
            :for={description <- @item.description}
            class="text-xl font-medium text-dark-text font-serif"
          >
            {description}
          </div>
          <div :if={@item.project} class="text-lg font-medium text-dark-text">
            Part of <a href="#">{@item.project}</a>
          </div>
          <.action_bar class="hidden sm:block" item={@item} />
          <.content_separator />
          <.metadata_table item={@item} />
        </div>
      </div>

      <div class="">
        <div class="bg-secondary">RELATED ITEMS</div>
      </div>
      <.share_modal item={@item} />
    </div>
    """
  end

  attr :rest, :global
  attr :item, :map, required: true

  def action_bar(assigns) do
    ~H"""
    <div {@rest}>
      <div class="flex flex-row justify-left items-center">
        <.action_icon icon="pepicons-pencil:ruler">
          Size
        </.action_icon>
        <.action_icon icon="hero-share" phx-click={JS.show(to: "#share-modal")}>
          Share
        </.action_icon>
        <div class="ml-auto h-full flex-grow pr-4">
          <.rights_icon rights_statement={@item.rights_statement} />
        </div>
      </div>
    </div>
    """
  end

  attr :rights_statement, :any, required: true

  def rights_icon(assigns) do
    ~H"""
    <img
      class="object-fit max-h-[30px] ml-auto"
      src={~p"/images/rights/#{rights_path(@rights_statement)}"}
      alt={@rights_statement}
    />
    """
  end

  def rights_path([rights_statement | _rest]), do: rights_path(rights_statement)

  def rights_path(rights_statement) when is_binary(rights_statement) do
    rights_path =
      rights_statement
      |> String.replace(~r/[^0-9a-zA-Z ]/, "")
      |> String.replace(" ", "-")
      |> String.downcase()

    "#{rights_path}.svg"
  end

  def rights_path(_), do: ""

  attr :rest, :global
  attr :icon, :string, required: true
  slot :inner_block, doc: "the optional inner block that renders the icon label"

  def action_icon(assigns) do
    ~H"""
    <div class="flex flex-col justify-center text-center text-sm mr-2 min-w-15 items-center">
      <button {@rest}>
        <div class="hover:text-white hover:bg-accent cursor-pointer w-10 h-10 p-2 bg-secondary rounded-full flex justify-center items-center">
          <.icon class="w-full h-full" name={@icon} />
        </div>
        {render_slot(@inner_block)}
      </button>
    </div>
    """
  end

  def primary_thumbnail(assigns) do
    ~H"""
    <div class="primary-thumbnail grid grid-cols-2 gap-2 content-start">
      <img
        class="col-span-2 w-full"
        src={"#{@item.primary_thumbnail_service_url}/full/525,800/0/default.jpg"}
        alt="main image display"
        style="
          background-color: lightgray;"
        width="525"
        height="800"
      />

      <.primary_button class="left-arrow-box">
        <.icon name="hero-eye" /> {gettext("View")}
      </.primary_button>

      <.download_button item={@item} />
    </div>
    """
  end

  def download_button(assigns = %{item: %{pdf_url: pdf_url}}) when is_binary(pdf_url) do
    ~H"""
    <.primary_button href={@item.pdf_url} target="_blank">
      <.icon name="hero-arrow-down-on-square" class="h-5" /><span>{gettext("Download")}</span>
    </.primary_button>
    """
  end

  def download_button(assigns) do
    ~H"""
    <.primary_button disabled>
      {gettext("No PDF Available")}
    </.primary_button>
    """
  end

  def hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(to: "#share-modal")
    |> JS.remove_class("bg-accent", to: "#copy-button")
  end

  def share_modal(assigns) do
    ~H"""
    <div id="share-modal" class="hidden">
      <div class="fixed inset-0 p-4 flex flex-wrap justify-center items-center w-full h-full z-[1000] before:fixed before:inset-0 before:w-full before:h-full before:bg-[rgba(0,0,0,0.5)] overflow-auto">
        <div
          class="w-full max-w-2xl bg-white shadow-lg rounded-lg p-8 relative"
          phx-click-away={hide_modal()}
        >
          <div class="flex items-center pb-3 border-b border-gray-300">
            <h3 class="text-xl font-semibold flex-1 text-slate-900">Share</h3>
            <button id="close-share" phx-click={hide_modal()} class="cursor-pointer">
              <.icon name="hero-x-mark" />
            </button>
          </div>
          <div>
            <div class="w-full rounded-lg overflow-hidden border border-gray-300 flex items-center mt-4">
              <p id="share-url" class="text-sm text-slate-500 flex-1 ml-4">
                {DpulCollectionsWeb.Endpoint.url()}{@item.url}
              </p>
              <button
                id="copy-button"
                phx-click={
                  JS.dispatch("dpulc:clipcopy", to: "#share-url") |> JS.add_class("bg-accent")
                }
                class="group btn-primary px-4 py-3 text-sm font-medium"
              >
                <span id="copy-text" class="group-[.bg-accent]:hidden">Copy</span>
                <span id="copied-text" class="not-group-[.bg-accent]:hidden">Copied</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block
  attr :class, :string, default: nil
  attr :href, :string, default: nil, doc: "link - if set it makes an anchor tag"
  attr :disabled, :boolean, default: false
  attr :rest, :global, doc: "the arbitrary HTML attributes to add link"

  def primary_button(assigns = %{href: href}) when href != nil do
    ~H"""
    <a href={@href} class={["btn-primary", "flex gap-2", @class]} {@rest}>
      <div>
        {render_slot(@inner_block)}
      </div>
    </a>
    """
  end

  def primary_button(assigns) do
    ~H"""
    <button class={["btn-primary flex gap-2", @class]} disabled={@disabled}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  def metadata_table(assigns) do
    ~H"""
    <div class="relative overflow-x-auto">
      <dl class="grid items-start gap-x-8 gap-y-4">
        <.metadata_row
          :for={{field, field_label} <- DpulCollections.Item.metadata_display_fields()}
          field_label={field_label}
          value={field_value(@item, field)}
        />
      </dl>
    </div>
    <.primary_button class="right-arrow-box">
      <.link id="metadata-link" navigate={~p"/item/#{@item.id}/metadata"}>
        <.icon name="hero-table-cells" />{gettext("View all metadata for this item")}
      </.link>
    </.primary_button>
    """
  end

  def metadata_row(%{value: []} = assigns) do
    ~H"""
    """
  end

  def metadata_row(assigns) do
    ~H"""
    <div class="col-span-2 grid grid-cols-subgrid border-b-1 border-rust pb-4">
      <dt class="font-bold text-lg">
        {@field_label}
      </dt>
      <dd :for={value <- @value} class="col-start-2">
        {value}
      </dd>
    </div>
    """
  end

  def field_value(item, field) do
    item
    |> Kernel.get_in([Access.key(field)])
    |> List.wrap()
  end

  def thumbs(assigns) do
    ~H"""
    <div class="pr-2 pb-2">
      <img
        class="h-full w-full object-cover"
        src={"#{@thumb}/full/350,465/0/default.jpg"}
        alt={"image #{@thumb_num}"}
        style="
          background-color: lightgray;"
      />
    </div>
    """
  end
end

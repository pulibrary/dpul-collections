defmodule DpulCollectionsWeb.ItemLive do
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

  def render(assigns) do
    ~H"""
    <div class="content-area item-page">
      <div class="column-layout my-5 flex flex-col sm:grid sm:grid-flow-row sm:auto-rows-0 sm:grid-cols-5 sm:grid-rows-[auto_1fr] sm:content-start gap-x-14 gap-y-4">
        <div class="item-title sm:row-start-1 sm:col-start-3 sm:col-span-3 h-min flex flex-col gap-4">
          <a class="text-xl uppercase tracking-wide">{@item.genre}</a>
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
          <p :if={@item.date} class="text-xl font-medium text-dark-blue">{@item.date}</p>
        </div>

        <div class="thumbnails w-full sm:row-start-1 sm:col-start-1 sm:col-span-2 sm:row-span-full">
          <.primary_thumbnail item={@item} />

          <.action_bar class="sm:hidden pt-4" item={@item} />

          <section class="page-thumbnails hidden sm:block md:col-span-2 py-4">
            <h2 class="py-4">{gettext("Pages")} ({@item.file_count})</h2>
            <div class="flex flex-wrap gap-5 justify-center md:justify-start">
              <.thumbs
                :for={{thumb, thumb_num} <- Enum.with_index(@item.image_service_urls)}
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
            class="text-xl font-medium text-dark-blue font-serif"
          >
            {description}
          </div>
          <div :for={collection <- @item.collection} class="text-lg font-medium text-dark-blue">
            Part of <a href="#">{collection}</a>
          </div>
          <.action_bar class="hidden sm:block" item={@item} />
          <.metadata_table item={@item} />
        </div>
      </div>

      <div class="">
        <div class="bg-cloud">RELATED ITEMS</div>
      </div>
    </div>
    """
  end

  attr :rest, :global
  attr :item, :map, required: true

  def action_bar(assigns) do
    ~H"""
    <div id="action-bar" {@rest}>
      <div class="flex flex-row justify-left items-center">
        <.action_icon icon="pepicons-pencil:ruler">
          Size
        </.action_icon>
        <.action_icon icon="hero-share">
          Share
        </.action_icon>
        <div class="ml-auto h-full flex-grow pr-4">
          <.rights_icon rights_statement={@item.rights_statement} />
        </div>
      </div>
      <.content_separator class="mt-4" />
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
      |> String.replace(~r/[^0-9a-zA-Z]"/, "")
      |> String.replace(" ", "-")
      |> String.downcase()

    "#{rights_path}.svg"
  end

  attr :rest, :global
  attr :icon, :string, required: true
  slot :inner_block, doc: "the optional inner block that renders the icon label"

  def action_icon(assigns) do
    ~H"""
    <div class="flex flex-col justify-center text-center text-sm mr-2 min-w-15 items-center">
      <button>
        <div class="hover:text-white hover:bg-rust cursor-pointer w-10 h-10 p-2 bg-wafer-pink rounded-full flex justify-center items-center">
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

      <button class="btn-primary">
        <a href="#" target="_blank">
          {gettext("View")}
        </a>
      </button>

      <button class="btn-primary">
        <a
          href={"#{Application.fetch_env!(:dpul_collections, :web_connections)[:figgy_url]}/catalog/#{@item.id}/pdf"}
          target="_blank"
        >
          {gettext("Download PDF")}
        </a>
      </button>
    </div>
    """
  end

  def metadata_table(assigns) do
    ~H"""
    <div class="relative overflow-x-auto shadow-md sm:rounded-lg">
      <table class="w-full text-sm text-left rtl:text-right align-top">
        <tbody>
          <.metadata_row
            :for={{field, _} <- Enum.with_index(DpulCollections.Item.metadata_display_fields())}
            field={field}
            value={field_value(@item, field)}
          />
        </tbody>
      </table>
    </div>
    """
  end

  def metadata_row(%{value: []} = assigns) do
    ~H"""
    """
  end

  def metadata_row(assigns) do
    ~H"""
    <tr class="even:bg-white odd:bg-gray-50 border-b border-gray-200">
      <th scope="row" class="px-6 py-4 text-gray-900 whitespace-nowrap align-top">
        {field_label(@field)}
      </th>
      <td class="px-6 py-4 font-medium">
        {@value}
      </td>
    </tr>
    """
  end

  def field_value(item, field) do
    item
    |> Kernel.get_in([Access.key(field)])
    |> List.wrap()
  end

  def field_label(field) do
    field
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def thumbs(assigns) do
    ~H"""
    <div>
      <img
        class="h-[465px] w-[350px] md:h-[300px] md:w-[225px]"
        src={"#{@thumb}/full/350,465/0/default.jpg"}
        alt={"image #{@thumb_num}"}
        style="
          background-color: lightgray;"
        width="350"
        height="465"
      />
      <button class="w-[350px] md:w-[225px] btn-primary">
        <a href={"#{@thumb}/full/full/0/default.jpg"} target="_blank">
          {gettext("Download")}
        </a>
      </button>
    </div>
    """
  end
end

defmodule DpulCollectionsWeb.ItemLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.Gettext
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
    <div class="my-5 grid grid-flow-row auto-rows-max md:grid-cols-5 gap-4">
      <div class="item md:col-span-3 md:pl-8">
        <h1 class="pb-2">{@item.title}</h1>
        <div class="md:block hidden">
          <.metadata_table item={@item} />
        </div>
      </div>
      <div class="primary-thumbnail md:col-span-2 md:order-first">
        <img
          class="w-full"
          src={"#{@item.primary_thumbnail_service_url}/full/525,800/0/default.jpg"}
          alt="main image display"
          style="
          background-color: lightgray;"
          width="525"
          height="800"
        />
        <button class="w-full btn-primary">
          <a
            href={"#{Application.fetch_env!(:dpul_collections, :web_connections)[:figgy_url]}/catalog/#{@item.id}/pdf"}
            target="_blank"
          >
            {gettext("Download PDF")}
          </a>
        </button>
      </div>
      <div class="md:hidden block">
        <.metadata_table item={@item} />
      </div>
      <section class="md:col-span-5 m:order-last py-4">
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

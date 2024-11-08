defmodule DpulCollectionsWeb.ItemLive do
  use DpulCollectionsWeb, :live_view
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

  defp build_socket(socket, item, _) do
    assign(socket, item: item)
  end

  # Render a message if no item was found in Solr.
  def render(assigns) when is_nil(assigns.item) do
    ~H"""
    <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
      <span>Item not found</span>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="my-5 grid grid-flow-row auto-rows-max md:grid-cols-5 gap-4">
      <div class="item md:col-span-3">
        <h1 class="text-xl font-bold py-2"><%= @item.title %></h1>
        <div class="pb-4"><%= @item.date %></div>
      </div>
      <div class="md:col-span-2 md:order-first">
        <img
          class="w-full"
          src="https://picsum.photos/525/800/?random"
          alt="main image display"
          style="
          background-color: lightgray;"
          width="525"
          height="800"
        />
        <button class="w-full btn-primary">
          Download
        </button>
      </div>
      <section class="md:col-span-5 m:order-last py-4">
        <h2 class="text-l font-bold py-4">Pages (<%= @item.page_count %>)</h2>
        <div class="flex flex-wrap gap-5 justify-center md:justify-start">
          <.thumbs
            :for={thumb_num <- 1..@item.page_count}
            :if={@item.page_count}
            thumb_num={thumb_num}
          />
        </div>
      </section>
    </div>
    """
  end

  def thumbs(assigns) do
    ~H"""
    <div>
      <img
        class="h-[465px] w-[350px] md:h-[300px] md:w-[225px]"
        src="https://picsum.photos/350/350/?random"
        alt={"image #{@thumb_num}"}
        style="
          background-color: lightgray;"
        width="350"
        height="465"
      />
      <button class="w-[350px] md:w-[225px] btn-primary">
        Download
      </button>
    </div>
    """
  end
end

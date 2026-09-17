defmodule DpulCollectionsWeb.OcrLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.DistributedOcr.Host

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:processed, [])
      |> assign(:processing, nil)

    Phoenix.PubSub.subscribe(DpulCollections.PubSub, "ocr")
    {:ok, socket}
  end

  def handle_info({:processed, job, ocr}, socket) do
    socket =
      socket
      |> assign(:processed, [{job, ocr} | socket.assigns.processed])

    {:noreply, socket}
  end

  def handle_info({:processing, job}, socket) do
    socket =
      socket
      |> assign(:processing, job)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} content_class={}>
      <div class="flex flex-col content-area page-y-padding gap-6">
        <h1>Now Running OCR on:</h1>
        <div :if={@processing} class="flex max-h-[300px]">
          <img src={@processing} class="object-contain" />
        </div>
        <hr />
        <div :for={{img, ocr} <- @processed} class="gap-6 grid grid-rows-1 grid-cols-2">
          <div class="flex max-h-[300px]">
            <img src={img} class="object-contain" />
          </div>
          <div>
            <p>
              {ocr}
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

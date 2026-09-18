defmodule DpulCollectionsWeb.OcrReaderLive do
  # Little book reader so I can watch the OCR stream in.
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.DistributedOcr

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DpulCollections.PubSub, "ocr")
    end

    {:ok, assign(socket, manifest_url: nil, pages: [])}
  end

  def handle_params(%{"manifest" => manifest_url}, _uri, socket) do
    {:noreply, socket |> assign(:manifest_url, manifest_url) |> load_pages()}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, push_navigate(socket, to: ~p"/ocr")}
  end

  def handle_info(:clients_changed, socket), do: {:noreply, load_pages(socket)}
  def handle_info(:refresh, socket), do: {:noreply, load_pages(socket)}

  def handle_event("retry_page", %{"image" => image_url}, socket) do
    DistributedOcr.Host.retry_page(image_url)
    {:noreply, socket}
  end

  def handle_event("retry_manifest", _params, socket) do
    DistributedOcr.Host.retry_manifest(socket.assigns.manifest_url)
    {:noreply, socket}
  end

  defp load_pages(socket) do
    pages = DistributedOcr.manifest_pages(socket.assigns.manifest_url)

    socket
    |> assign(:pages, pages)
    |> assign(:title, title(pages, socket.assigns.manifest_url))
    |> assign(:done_count, Enum.count(pages, & &1.done))
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="ocr-reader" class="flex flex-col">
        <div class="content-area page-t-padding flex flex-wrap items-baseline justify-between gap-3">
          <div class="flex flex-col">
            <.link navigate={~p"/ocr"} class="filter-link text-tiny">← All books</.link>
            <h1 class="heading" dir="auto">{@title}</h1>
          </div>
          <div :if={@pages != []} class="flex flex-col items-end gap-1">
            <p class="text-tiny">
              {@done_count} of {length(@pages)} {ngettext("page read", "pages read", length(@pages))}
            </p>
            <button
              type="button"
              phx-click="retry_manifest"
              data-confirm="Re-read every page of this book? Existing transcriptions are discarded."
              class="filter-link text-tiny cursor-pointer"
            >
              ↻ Re-read all pages
            </button>
          </div>
        </div>

        <p :if={@pages == []} class="content-area page-y-padding font-serif">
          Waiting for the first page of this book…
        </p>

        <div class="flex flex-col">
          <section
            :for={{page, i} <- Enum.with_index(@pages)}
            class="w-full py-10 odd:bg-sage-100 even:bg-background border-t border-sage-300 first:border-t-0"
          >
            <div class="content-area grid gap-8 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)] items-start">
              <figure class="flex flex-col items-center gap-2">
                <div class="bg-white p-2 shadow-[0.5rem_0.5rem_1.5rem_var(--color-sage-400)] max-w-full">
                  <img
                    src={page.image_url}
                    alt={page.page_label || "page #{i + 1}"}
                    loading="lazy"
                    class="max-h-[85vh] w-auto object-contain"
                  />
                </div>
                <figcaption class="text-tiny">
                  {page.page_label || gettext("Page %{n}", n: i + 1)}
                </figcaption>
              </figure>

              <div class="lg:sticky lg:top-6">
                <div class="flex items-baseline justify-between mb-3">
                  <p class="text-tiny">Transcription</p>
                  <button
                    type="button"
                    phx-click="retry_page"
                    phx-value-image={page.image_url}
                    data-confirm={page.done && "Re-read this page? Its transcription is discarded."}
                    class="filter-link text-tiny cursor-pointer"
                  >
                    ↻ {if page.done, do: "Re-read", else: "Retry"}
                  </button>
                </div>
                <div
                  :if={page.done}
                  class="font-serif leading-relaxed whitespace-pre-wrap"
                  dir="auto"
                >
                  {page.text |> raw}
                </div>
                <div :if={!page.done} class="font-serif text-sage-600 italic">
                  This page hasn't been read yet — it'll appear here automatically.
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp title([%{manifest_label: label} | _], _url) when is_binary(label), do: label
  defp title(_pages, url), do: url
end

defmodule DpulCollectionsWeb.OcrResultsLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.DistributedOcr

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"manifest" => manifest_url}, _uri, socket) do
    socket =
      socket
      |> assign(:manifest_url, manifest_url)
      |> assign(:results, DistributedOcr.results_for_manifest(manifest_url))

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> assign(:manifest_url, nil)
      |> assign(:manifests, DistributedOcr.list_result_manifests())

    {:noreply, socket}
  end

  def render(%{manifest_url: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col content-area gap-6">
        <h1 class="heading">OCR Results</h1>
        <p :if={@manifests == []} class="font-serif">No OCR results yet.</p>
        <div class="flex flex-col gap-3">
          <.link
            :for={m <- @manifests}
            patch={~p"/ocr/results?#{[manifest: m.manifest_url]}"}
            class="card card-link p-4 flex justify-between items-baseline gap-4"
          >
            <span class="font-sans font-medium">
              {m.manifest_label || m.manifest_url}
            </span>
            <span class="text-tiny">
              {m.count} pages · {format_time(m.last_run_at)}
            </span>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col content-area gap-6">
        <.link patch={~p"/ocr/results"} class="filter-link">← All manifests</.link>
        <h1 class="heading">{manifest_title(@results, @manifest_url)}</h1>
        <div :for={r <- @results} class="gap-6 grid grid-rows-1 grid-cols-2 card p-4">
          <div class="flex flex-col gap-2">
            <div class="flex max-h-[300px]">
              <img src={r.image_url} class="object-contain" alt={r.page_label} />
            </div>
            <div class="text-tiny">
              {r.page_label} · {r.model} v{r.model_version} · {r.client_id} · {format_time(
                r.inserted_at
              )}
            </div>
          </div>
          <div class="font-serif" dir="auto">
            {r.text |> to_string() |> String.replace("\n", "<br />") |> raw()}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp manifest_title([%{manifest_label: label} | _], _url) when is_binary(label), do: label
  defp manifest_title(_results, url), do: url

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end

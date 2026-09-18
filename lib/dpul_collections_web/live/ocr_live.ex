defmodule DpulCollectionsWeb.OcrLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.DistributedOcr

  @refresh_ms 5_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DpulCollections.PubSub, "ocr")
      Process.send_after(self(), :refresh, @refresh_ms)
    end

    {:ok, load(socket)}
  end

  def handle_info(:refresh, socket) do
    # TODO: Do I even need this?? Could just rely on pubsub now that I think
    # about it.
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, load(socket)}
  end

  def handle_info(:clients_changed, socket) do
    {:noreply, load(socket)}
  end

  def handle_event("add_manifest", %{"manifest" => url}, socket) do
    socket =
      case add_manifest(String.trim(url)) do
        {:ok, 0} ->
          put_flash(socket, :info, "No new pages — those were already queued.")

        {:ok, count} ->
          put_flash(socket, :info, "Queued #{count} #{ngettext("page", "pages", count)} for OCR.")

        {:error, message} ->
          put_flash(socket, :error, "Couldn't add that manifest: #{message}")
      end

    {:noreply, load(socket)}
  end

  defp add_manifest(""), do: {:error, "please paste a manifest URL"}

  defp add_manifest(url) do
    DistributedOcr.Host.ocr_manifest(url)
  catch
    :exit, _ -> {:error, "the OCR host didn't respond"}
  end

  defp load(socket) do
    clients = DistributedOcr.connected_clients()

    socket
    |> assign(:clients, clients)
    |> assign(:working, Enum.count(clients, &(&1.status == "working")))
    |> assign(:manifests, DistributedOcr.list_requested_manifests())
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col content-area page-y-padding gap-8">
        <div class="flex flex-wrap items-baseline justify-between gap-4">
          <div>
            <p class="text-tiny">Distributed OCR</p>
            <h1 class="heading">Books being read</h1>
          </div>
          <p class="text-tiny">
            {length(@clients)} clients connected · {@working} working
          </p>
        </div>

        <form phx-submit="add_manifest" class="flex flex-wrap items-stretch gap-2 max-w-2xl">
          <input
            type="url"
            name="manifest"
            required
            placeholder="Paste a IIIF manifest URL to read a new book…"
            class="flex-1 min-w-[16rem] border border-sage-400 bg-white px-4 py-3 font-sans focus:outline-none focus:border-accent"
          />
          <button
            type="submit"
            class="bg-accent text-light-text px-6 font-sans font-medium uppercase text-tiny cursor-pointer hover:bg-[#c67355]"
          >
            Add book
          </button>
        </form>

        <div :if={@manifests == []} class="font-serif">
          No books have been requested yet.
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-6">
          <.link
            :for={m <- @manifests}
            navigate={~p"/ocr/read?#{[manifest: m.manifest_url]}"}
            class="card card-link group flex flex-col gap-3"
          >
            <div class="aspect-[3/4] overflow-hidden bg-sage-100 border border-sage-300">
              <img
                src={m.cover_image_url}
                alt={m.manifest_label || m.manifest_url}
                loading="lazy"
                class="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
              />
            </div>
            <div class="flex flex-col gap-1">
              <span class="font-sans font-medium leading-tight" dir="auto">
                {m.manifest_label || m.manifest_url}
              </span>
              <span class="text-tiny">{progress_label(m)}</span>
              <div class="h-1 w-full bg-sage-200 overflow-hidden">
                <div class="h-full bg-accent" style={"width: #{progress_pct(m)}%"}></div>
              </div>
            </div>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp progress_label(%{done: done, total: total}) do
    "#{done} of #{total} #{ngettext("page read", "pages read", total)}"
  end

  defp progress_pct(%{total: total}) when total in [0, nil], do: 0
  defp progress_pct(%{done: done, total: total}), do: round(done / total * 100)
end

defmodule DpulCollectionsWeb.GeoreferencerLive.Volunteer do
  @moduledoc """
  The volunteer page: while it is open, the visitor's browser takes jobs from
  the queue and georeferences them in a Web Worker (the `GeorefVolunteer`
  hook); finished sheets appear on the map for everyone watching.
  """
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Georef.Collab.Queue

  def mount(_params, _session, socket) do
    if connected?(socket), do: Queue.subscribe()

    socket =
      socket
      |> assign(page_title: "Georeference with us", manifest: "", queueing: false)
      |> assign_counts()

    {:ok, socket}
  end

  defp assign_counts(socket) do
    assign(socket, counts: Queue.counts(), atlases: Queue.atlas_counts())
  end

  defp user(socket) do
    case socket.assigns[:current_scope] do
      %{user: u} -> u
      _ -> nil
    end
  end

  # the hook asks once it has loaded (an event pushed at mount would arrive before it listens)
  def handle_event("recent", _, socket), do: {:reply, %{items: Queue.recent()}, socket}

  def handle_event("claim", %{"worker" => worker}, socket) do
    {:reply, %{job: Queue.claim(worker, user(socket))}, socket}
  end

  def handle_event("complete", %{"job_id" => id, "worker" => worker, "result" => result}, socket) do
    case Queue.complete(id, worker, user(socket), result) do
      :ok -> {:reply, %{ok: true}, socket}
      {:error, why} -> {:reply, %{ok: false, error: to_string(why)}, socket}
    end
  end

  def handle_event("fail", %{"job_id" => id, "worker" => worker, "error" => error}, socket) do
    Queue.fail(id, worker, error)
    {:reply, %{ok: true}, socket}
  end

  def handle_event("queue", %{"manifest" => url}, socket) do
    url = String.trim(url)

    if url =~ ~r{\Ahttps://[^\s]+\z} do
      {:noreply,
       socket
       |> assign(queueing: true, manifest: url)
       |> start_async(:queue, fn -> Queue.enqueue(url) end)}
    else
      {:noreply, put_flash(socket, :error, "Paste an IIIF manifest URL.")}
    end
  end

  def handle_async(:queue, {:ok, atlas}, socket) do
    {:noreply,
     socket
     |> assign(queueing: false, manifest: "")
     |> put_flash(:info, "Queued #{atlas.label}: #{length(atlas.canvases)} sheets.")
     |> assign_counts()}
  end

  def handle_async(:queue, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(queueing: false)
     |> put_flash(
       :error,
       "Couldn't queue that manifest: #{inspect(reason) |> String.slice(0, 200)}"
     )}
  end

  def handle_info({:georef_result, item}, socket) do
    {:noreply, socket |> push_event("result", item) |> assign_counts()}
  end

  def handle_info(:queue_changed, socket) do
    {:noreply, socket |> push_event("wake", %{}) |> assign_counts()}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-3">
        <div class="flex flex-wrap items-baseline gap-x-6 gap-y-1 pb-2">
          <h1 class="heading text-2xl">Georeference Sanborn maps with us</h1>
          <span class="text-sm">
            {Map.get(@counts, "done", 0)} sheets done · {Map.get(@counts, "claimed", 0)} in progress · {Map.get(
              @counts,
              "queued",
              0
            )} waiting
          </span>
          <.link class="filter-link text-sm" navigate={~p"/georeferencer"}>Atlases and your results</.link>
        </div>
        <p class="max-w-3xl pb-3 font-serif text-sm">
          While this page is open your computer takes sheets from the queue and places them on the
          modern map: it reads the street names, searches the town on your graphics card for where they
          fit and checks the printed streets line up. Finished sheets appear on the map below.
          <span :if={!@current_scope || !@current_scope.user}>
            <.link class="filter-link" navigate={~p"/users/log-in"}>Log in</.link>
            to be credited for your results.
          </span>
        </p>
        <div
          id="georef-volunteer"
          phx-hook="GeorefVolunteer"
          phx-update="ignore"
          data-worker={DpulCollectionsWeb.Endpoint.static_path("/assets/js/georef_worker.js")}
          class="grid gap-3 lg:grid-cols-[22rem_1fr]"
        >
        </div>
        <details class="pt-4 text-sm max-w-3xl">
          <summary class="cursor-pointer">Queue</summary>
          <form phx-submit="queue" class="flex gap-2 py-2">
            <input
              name="manifest"
              value={@manifest}
              placeholder="IIIF manifest URL of an atlas"
              class="grow border border-sage-400 px-2 py-1"
            />
            <button class="btn-primary px-3 py-1" disabled={@queueing}>
              {if @queueing, do: "Preparing…", else: "Queue atlas"}
            </button>
          </form>
          <table class="w-full">
            <tr :for={a <- @atlases} class="border-t border-sage-300">
              <td class="py-0.5">{a.label}</td>
              <td>{Map.get(a.counts, "done", 0)} done</td>
              <td>{Map.get(a.counts, "claimed", 0)} in progress</td>
              <td>{Map.get(a.counts, "queued", 0)} waiting</td>
              <td>{Map.get(a.counts, "failed", 0)} failed</td>
              <td>
                <a class="filter-link" href={~p"/georeferencer/atlas/#{a.id}/georef.json"}>JSON</a>
              </td>
            </tr>
          </table>
        </details>
      </div>
    </Layouts.app>
    """
  end
end

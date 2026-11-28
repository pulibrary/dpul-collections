defmodule DpulCollectionsWeb.Georeferencer.QueueLive do
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
      |> assign(page_title: "Georeference with us", manifest: "", queueing: false, to_review: 0)
      |> assign_counts()
      |> then(&if(connected?(&1), do: assign_review(&1), else: &1))

    {:ok, socket}
  end

  defp assign_counts(socket) do
    assign(socket, counts: Queue.counts(), atlases: Queue.atlas_counts())
  end

  # parts waiting for a person: costly (it reads every atlas), so off the page's
  # critical path and shared between tabs (Review.count/0)
  defp assign_review(socket) do
    start_async(socket, :to_review, fn -> DpulCollections.Georef.Collab.Review.count() end)
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
    {:reply, %{job: Queue.claim(worker, user(socket))}, assign(socket, worker: worker)}
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

  # the browser lost its GPU (the machine slept, a driver reset): not the sheet's fault, so the
  # job goes back without using up a try
  def handle_event("release", %{"worker" => worker}, socket) do
    Queue.release(worker)
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

  def handle_async(:to_review, {:ok, n}, socket), do: {:noreply, assign(socket, to_review: n)}
  def handle_async(:to_review, {:exit, _}, socket), do: {:noreply, socket}

  def handle_async(:queue, {:ok, atlas}, socket) do
    {:noreply,
     socket
     |> assign(queueing: false, manifest: "")
     |> put_flash(:info, "Queued #{atlas.label}: #{sheets(length(atlas.canvases))}.")
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

  # the tab closed or reloaded mid-sheet: put its sheet back for someone else
  def terminate(_reason, socket) do
    if w = socket.assigns[:worker], do: Queue.release(w)
    :ok
  end

  def handle_info({:georef_result, item}, socket) do
    {:noreply, socket |> push_event("result", item) |> assign_counts() |> assign_review()}
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
          <a
            :if={@to_review > 0}
            class="btn-primary px-3 py-1 text-sm"
            href={~p"/georeferencer/review"}
            target="_blank"
          >
            {@to_review} {if @to_review == 1, do: "sheet needs", else: "sheets need"} a person: place them ↗
          </a>
          <.link class="filter-link text-sm" navigate={~p"/georeferencer/results"}>
            Your results and downloads
          </.link>
        </div>
        <p class="max-w-3xl pb-3 font-serif text-sm">
          Keep this page open and your computer helps: it takes the next sheet from the queue
          automatically, reads its street names, searches the town on your graphics card for where they
          fit and checks that the printed streets line up. Finished sheets appear on the map.
          <span :if={!@current_scope || !@current_scope.user}>
            <.link class="filter-link" navigate={~p"/users/log-in"}>Log in</.link>
            to be credited for your results.
          </span>
        </p>

        <div
          id="georef-volunteer"
          phx-hook="GeorefVolunteer"
          phx-update="ignore"
          data-worker={DpulCollectionsWeb.Endpoint.static_path("/assets/js/georeferencer/worker.js")}
          class="grid gap-3 lg:grid-cols-[22rem_1fr]"
        >
        </div>
        <section id="georef-queue" class="pt-4 text-xs">
          <div class="flex flex-wrap items-center gap-x-4 gap-y-1 pb-1">
            <h2 class="heading text-base">Queue</h2>
            <span>
              {Map.get(@counts, "queued", 0)} sheets waiting · {Map.get(@counts, "claimed", 0)} being worked on · {Map.get(
                @counts,
                "done",
                0
              )} done
            </span>
            <form id="queue-atlas" phx-submit="queue" class="flex gap-1 grow max-w-xl">
              <input
                name="manifest"
                value={@manifest}
                placeholder="Add an atlas: paste its IIIF manifest URL"
                class="grow h-7 border border-sage-400 px-2 text-xs"
              />
              <button class="btn-primary h-7 px-3 text-xs" disabled={@queueing}>
                {if @queueing, do: "Preparing…", else: "Add"}
              </button>
            </form>
          </div>
          <p :if={@atlases == []}>
            Nothing queued yet. Add an atlas and every open copy of this page starts on it.
          </p>
          <div :if={@atlases != []} class="max-h-72 overflow-y-auto border-t border-sage-300">
            <table class="w-full">
              <tbody>
                <tr :for={a <- @atlases} class="border-b border-sage-200">
                  <td class="py-0.5 pr-2 truncate max-w-[28rem]" title={a.label}>{a.label}</td>
                  <td class="w-28 pr-2">
                    <div class="h-1.5 bg-sage-200" title={"#{progress(a)}% finished"}>
                      <div class="h-1.5 bg-sage-600" style={"width: #{progress(a)}%"}></div>
                    </div>
                  </td>
                  <td class="whitespace-nowrap pr-2 text-stone-600">
                    {a.sheets_done}/{a.sheets} sheets{if Map.get(a.counts, "claimed", 0) > 0,
                      do: " · #{Map.get(a.counts, "claimed", 0)} working"}{if a.sheets_done > 0 and
                                                                                Map.get(
                                                                                  a.counts,
                                                                                  "queued",
                                                                                  0
                                                                                ) > 0,
                                                                              do:
                                                                                " · #{Map.get(a.counts, "queued", 0)} waiting"}{if Map.get(
                                                                                                                                     a.counts,
                                                                                                                                     "failed",
                                                                                                                                     0
                                                                                                                                   ) >
                                                                                                                                     0,
                                                                                                                                   do:
                                                                                                                                     " · #{Map.get(a.counts, "failed", 0)} failed"}
                  </td>
                  <td class="whitespace-nowrap text-right">
                    <a
                      class="filter-link"
                      href={"https://viewer.allmaps.org/?url=" <> URI.encode_www_form(url(~p"/georeferencer/atlas/#{a.id}/georef.json"))}
                      target="_blank"
                    >Allmaps</a>
                    ·
                    <a class="filter-link" href={~p"/georeferencer/atlas/#{a.id}/georef.json"}>JSON</a>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  # finished (done or given up) jobs out of all jobs, rename rounds included
  defp progress(%{counts: c}) do
    total = c |> Map.values() |> Enum.sum()
    finished = Map.get(c, "done", 0) + Map.get(c, "failed", 0)
    if total == 0, do: 0, else: round(100 * finished / total)
  end

  defp sheets(1), do: "1 sheet"
  defp sheets(n), do: "#{n} sheets"
end

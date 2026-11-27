defmodule DpulCollectionsWeb.GeoreferencerLive.Sheet do
  @moduledoc """
  One map part in the collaborative georeferencer. The `Georeferencer` JS hook
  does the fitting on the contributor's machine (WebGPU) and pushes the result
  here only to be saved.
  """
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Georef.Collab

  def mount(%{"atlas" => id, "index" => i}, _session, socket) do
    atlas = Collab.atlas(id) || raise DpulCollectionsWeb.ItemLive.NotFoundError
    {i, ""} = Integer.parse(i)

    {:ok,
     socket
     |> assign(atlas: atlas, page_title: "Georeferencer · #{atlas["label"]}")
     |> assign(index: i)
     |> load_status()}
  end

  def handle_params(%{"index" => i}, _uri, socket) do
    {i, ""} = Integer.parse(i)
    {:noreply, assign(socket, index: i, canvas: Enum.at(socket.assigns.atlas["canvases"], i))}
  end

  defp load_status(socket) do
    assign(socket, latest: Collab.latest_by_part(socket.assigns.atlas["id"]))
  end

  def handle_event("save", params, socket) do
    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        case Collab.save(user, socket.assigns.atlas, socket.assigns.index, params) do
          {:ok, c} ->
            {:reply, %{ok: true, id: c.id, url: ~p"/georeferencer/contributions/#{c.id}"},
             load_status(socket)}

          {:error, cs} ->
            {:reply, %{ok: false, error: inspect(cs.errors)}, socket}
        end

      _ ->
        {:reply, %{ok: false, error: "Log in to save your result."}, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-3 flex flex-col lg:flex-row gap-4">
        <nav class="lg:w-64 shrink-0 text-sm" aria-label="Parts of this atlas">
          <.link class="filter-link" navigate={~p"/georeferencer"}>All atlases</.link>
          <h1 class="heading text-lg py-2">{@atlas["label"]}</h1>
          <ol class="max-h-[70vh] overflow-y-auto">
            <li :for={{c, j} <- Enum.with_index(@atlas["canvases"])}>
              <.link
                patch={~p"/georeferencer/#{@atlas["id"]}/#{j}"}
                class={[
                  "flex gap-2 items-center px-1 py-0.5",
                  j == @index && "bg-sage-200 font-semibold"
                ]}
              >
                <span
                  class={["inline-block w-2.5 h-2.5 rounded-full", dot(c, @latest)]}
                  title={status(c, @latest)}
                ></span>
                {c["label"]}
              </.link>
            </li>
          </ol>
          <ul class="pt-3 text-xs space-y-1">
            <li>
              <span class="inline-block w-2.5 h-2.5 rounded-full bg-emerald-600"></span>
              placed by a volunteer
            </li>
            <li>
              <span class="inline-block w-2.5 h-2.5 rounded-full bg-sky-500"></span>
              server prototype fit only
            </li>
            <li>
              <span class="inline-block w-2.5 h-2.5 rounded-full bg-amber-500"></span> not placed yet
            </li>
            <li>
              <span class="inline-block w-2.5 h-2.5 rounded-full bg-stone-400"></span>
              marked "can't place"
            </li>
          </ul>
        </nav>

        <section class="grow min-w-0">
          <div class="flex flex-wrap items-baseline gap-x-4 pb-2">
            <h2 class="heading text-xl">{@canvas["label"]}</h2>
            <span class="text-sm">{status(@canvas, @latest)}</span>
            <span :if={!@current_scope || !@current_scope.user} class="text-sm">
              <.link class="filter-link" navigate={~p"/users/log-in"}>Log in</.link> to save results.
            </span>
          </div>
          <div
            id={"georeferencer-#{@index}"}
            phx-hook="Georeferencer"
            phx-update="ignore"
            data-input={~p"/georeferencer/input/#{@atlas["id"]}/#{@index}"}
            data-image={~p"/georeferencer/image"}
          >
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp key(c), do: {c["id"], c["part"]}

  defp status(c, latest) do
    case latest[key(c)] do
      %{verdict: "placed", method: m} -> "placed by a volunteer (#{m})"
      %{verdict: "cannot"} -> "marked can't place"
      nil -> if c["status"] == "ok", do: "server prototype fit only", else: "not placed yet"
    end
  end

  defp dot(c, latest) do
    case latest[key(c)] do
      %{verdict: "placed"} -> "bg-emerald-600"
      %{verdict: "cannot"} -> "bg-stone-400"
      nil -> if c["status"] == "ok", do: "bg-sky-500", else: "bg-amber-500"
    end
  end
end

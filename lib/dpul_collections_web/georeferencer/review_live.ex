defmodule DpulCollectionsWeb.Georeferencer.ReviewLive do
  @moduledoc """
  Placing by hand the parts volunteers' browsers weren't sure about, easiest
  first. Saving moves on to the next one.
  """
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Georef.Collab
  alias DpulCollections.Georef.Collab.{Queue, Review}

  @tiers %{
    1 => "Probably right: check it",
    2 => "Lands on top of another sheet",
    3 => "Place by its street names",
    4 => "Little to go on"
  }

  def mount(_params, _session, socket) do
    if connected?(socket), do: Queue.subscribe()
    {:ok, assign(socket, page_title: "Place sheets by hand", items: Review.items())}
  end

  def handle_params(%{"atlas" => atlas, "index" => i}, _uri, socket) do
    {:noreply,
     assign(socket, current: {atlas, DpulCollectionsWeb.Georeferencer.SheetLive.index!(i)})}
  end

  def handle_params(_params, _uri, socket) do
    # start on the easiest
    {:noreply,
     assign(socket, current: socket.assigns.items |> List.first() |> then(&(&1 && key(&1))))}
  end

  def handle_event("save", params, socket) do
    user = with %{user: user} <- socket.assigns.current_scope, do: user
    {atlas_id, i} = socket.assigns.current || {nil, nil}
    atlas = atlas_id && Collab.atlas(atlas_id)

    cond do
      user == nil ->
        {:reply, %{ok: false, error: "Log in to save your result."}, socket}

      atlas == nil ->
        {:reply, %{ok: false, error: "That atlas is no longer in the queue."}, socket}

      true ->
        case Collab.save(user, atlas, i, params) do
          {:ok, c} ->
            announce(atlas, i, params, user)
            items = Review.items()
            next = next_item(items, socket.assigns.current)
            socket = assign(socket, items: items)
            socket = if next, do: push_patch(socket, to: item_path(next)), else: socket
            {:reply, %{ok: true, id: c.id, url: ~p"/georeferencer/contributions/#{c.id}"}, socket}

          {:error, cs} ->
            {:reply, %{ok: false, error: inspect(cs.errors)}, socket}
        end
    end
  end

  def handle_event("skip", _, socket) do
    case next_item(socket.assigns.items, socket.assigns.current) do
      nil -> {:noreply, socket}
      next -> {:noreply, push_patch(socket, to: item_path(next))}
    end
  end

  # new sheets finished in volunteers' browsers may need a person too
  def handle_info({:georef_result, _}, socket),
    do: {:noreply, assign(socket, items: Review.items())}

  def handle_info(_, socket), do: {:noreply, socket}

  # a part placed by hand shows up on everyone's volunteer map
  defp announce(atlas, i, %{"verdict" => "placed", "transform" => t}, user) do
    c = Enum.at(atlas["canvases"], i)
    part = %{"part" => c["part"], "status" => "ok", "mask" => c["mask"], "transform" => t}

    Phoenix.PubSub.broadcast(
      DpulCollections.PubSub,
      Queue.topic(),
      {:georef_result, Queue.feed_item(atlas, c, [part], user)}
    )
  end

  defp announce(_, _, _, _), do: :ok

  # the item after the current one (the list may have changed under us)
  defp next_item(items, current) do
    rest = Enum.drop_while(items, &(key(&1) != current))

    case rest do
      [_ | [next | _]] -> next
      [_] -> List.first(items -- rest)
      [] -> List.first(items)
    end
  end

  defp key(item), do: {item.atlas_id, item.index}
  defp item_path(item), do: ~p"/georeferencer/review/#{item.atlas_id}/#{item.index}"

  def render(assigns) do
    assigns =
      assign(assigns,
        tiers: @tiers,
        groups: Enum.group_by(assigns.items, & &1.tier) |> Enum.sort(),
        item: Enum.find(assigns.items, &(key(&1) == assigns.current))
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-3 flex flex-col lg:flex-row gap-4">
        <nav class="lg:w-80 shrink-0 text-sm" aria-label="Sheets to place">
          <h1 class="heading text-xl">Place sheets by hand</h1>
          <p class="pb-2">
            {length(@items)} parts the computers weren't sure about, easiest first.
            <.link class="filter-link" navigate={~p"/georeferencer"}>Queue</.link>
          </p>
          <p :if={@items == []} class="py-4">Nothing needs a person right now.</p>
          <div class="max-h-[78vh] overflow-y-auto pr-1">
            <section :for={{tier, items} <- @groups} class="pb-3">
              <h2 class="font-semibold py-1">{@tiers[tier]} ({length(items)})</h2>
              <ol>
                <li :for={it <- items}>
                  <.link
                    patch={item_path(it)}
                    class={[
                      "flex gap-2 items-center p-1 border-l-4",
                      if({it.atlas_id, it.index} == @current,
                        do: "bg-sage-200 border-accent",
                        else: "border-transparent"
                      )
                    ]}
                  >
                    <img
                      src={"#{it.service}/#{it.region}/!64,64/0/default.jpg"}
                      alt=""
                      loading="lazy"
                      class="w-16 h-16 object-contain bg-white shrink-0"
                    />
                    <span class="min-w-0">
                      <span class="block font-medium">{it.label}</span>
                      <span class="block text-xs truncate">{it.atlas_label}</span>
                      <span class="block text-xs text-stone-600">{it.why}</span>
                    </span>
                  </.link>
                </li>
              </ol>
            </section>
          </div>
        </nav>

        <section :if={@current} class="grow min-w-0">
          <div class="flex flex-wrap items-baseline gap-x-4 pb-2">
            <h2 class="heading text-xl">{@item && @item.label}</h2>
            <span :if={@item} class="text-sm">{@item.atlas_label} · {@item.why}</span>
            <span class="grow"></span>
            <button phx-click="skip" class="btn-secondary px-3 py-1 text-sm">Skip</button>
          </div>
          <p :if={!@current_scope || !@current_scope.user} class="text-sm pb-2">
            <.link class="filter-link" navigate={~p"/users/log-in"}>Log in</.link>
            to save your placements.
          </p>
          <div
            id={"review-#{elem(@current, 0)}-#{elem(@current, 1)}"}
            phx-hook="Georeferencer"
            phx-update="ignore"
            data-input={~p"/georeferencer/input/#{elem(@current, 0)}/#{elem(@current, 1)}"}
            data-image={~p"/georeferencer/image"}
          >
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end

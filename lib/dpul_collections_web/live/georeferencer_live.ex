defmodule DpulCollectionsWeb.GeoreferencerLive do
  @moduledoc """
  Collaborative georeferencer: pick an atlas, see your contributions.
  The work itself happens in GeoreferencerLive.Sheet, in the browser.
  """
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Georef.Collab

  def mount(_params, _session, socket) do
    counts = Collab.counts_by_atlas()

    atlases =
      Collab.list_atlases()
      |> Enum.map(&Map.put(&1, :volunteer, Map.get(counts, &1.id, 0)))
      |> Enum.sort_by(& &1.label)

    mine =
      case socket.assigns.current_scope do
        %{user: user} when user != nil -> Collab.list_for_user(user)
        _ -> nil
      end

    {:ok, assign(socket, atlases: atlases, mine: mine, page_title: "Georeferencer")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="georeferencer" class="content-area">
        <h1 class="heading text-3xl pb-2">Collaborative georeferencer</h1>
        <p class="max-w-3xl pb-6 font-serif">
          Help place Sanborn fire insurance maps on the modern map. Your computer does the work:
          it reads each sheet, searches the town's streets on your graphics card for where the
          sheet's street names fit, and shows you the result to confirm or adjust. What you save
          is credited to you and downloadable below.
        </p>

        <section :if={@mine} class="pb-8" id="my-contributions">
          <h2 class="heading text-xl pb-2">Your contributions ({length(@mine)})</h2>
          <p :if={@mine == []} class="text-sm">None yet: open an atlas below.</p>
          <table :if={@mine != []} class="text-sm w-full max-w-4xl">
            <thead>
              <tr class="text-left">
                <th>Atlas</th><th>Part</th><th>Result</th><th>Saved</th><th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={c <- @mine} class="border-t border-sage-300">
                <td>{c.atlas_label}</td>
                <td>{c.canvas_label}</td>
                <td>{verdict(c)}</td>
                <td>{Calendar.strftime(c.inserted_at, "%Y-%m-%d %H:%M")}</td>
                <td class="flex gap-3">
                  <a class="filter-link" href={~p"/georeferencer/contributions/#{c.id}"}>JSON</a>
                  <a
                    class="filter-link"
                    href={"https://viewer.allmaps.org/?url=" <> URI.encode_www_form(url(~p"/georeferencer/contributions/#{c.id}"))}
                    target="_blank"
                  >Allmaps</a>
                </td>
              </tr>
            </tbody>
          </table>
        </section>
        <p :if={!@mine} class="pb-6 text-sm">
          <.link class="filter-link" navigate={~p"/users/log-in"}>Log in</.link>
          to save results and get credit for them. You can try the tool without an account.
        </p>

        <h2 class="heading text-xl pb-2">Atlases</h2>
        <table class="text-sm w-full max-w-4xl">
          <thead>
            <tr class="text-left">
              <th>Atlas</th><th>Parts</th><th>Automatic fits</th><th>Volunteer results</th><th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={a <- @atlases} class="border-t border-sage-300">
              <td>
                <.link class="filter-link" navigate={~p"/georeferencer/#{a.id}/0"}>{a.label}</.link>
              </td>
              <td>{a.parts}</td>
              <td>
                {a.server_ok}
                <span class="text-xs">({if a.source == :queue,
                  do: "volunteers' browsers",
                  else: "server prototype"})</span>
              </td>
              <td>{a.volunteer}</td>
              <td>
                <a class="filter-link" href={~p"/georeferencer/atlas/#{a.id}/georef.json"}>JSON</a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  defp verdict(%{verdict: "placed", method: m}), do: "placed (#{m})"
  defp verdict(%{verdict: v}), do: v
end

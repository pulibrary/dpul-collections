defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.Gettext
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.Live.Helpers

  def mount(params, _session, socket) do
    # default to English if locale is not provided
    locale = Map.get(params, "locale", "en")
    set_locale(locale)

    socket =
      assign(socket,
        item_count: Solr.document_count(),
        q: nil,
        locale: locale
      )

    {:ok, socket, temporary_assigns: [item_count: nil]}
  end

  defp set_locale(locale) do
    Gettext.put_locale(DpulCollectionsWeb.Gettext, locale)
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-flow-row auto-rows-max gap-20">
      <div>
        <form phx-submit="search">
          <div class="grid grid-cols-4">
            <input class="col-span-4 md:col-span-3" type="text" name="q" value={@q} />
            <button class="col-span-4 md:col-span-1 btn-primary" type="submit">
              <%= gettext("Search") %>
            </button>
          </div>
        </form>
      </div>
      <div id="welcome" class="grid place-self-center gap-10 max-w-prose">
        <h3 class="text-5xl text-center">Explore Our Digital Collections</h3>
        <p class="text-xl text-center">
          We invite you to be inspired by our globally diverse collections of <%= @item_count %> Ephemera items. We can't wait to see how you use these materials to support your unique research.
        </p>
      </div>
    </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{locale: socket.assigns.locale, q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end

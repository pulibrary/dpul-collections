defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.{Item, Solr}
  alias DpulCollectionsWeb.MosaicImages

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Digital Collections",
        q_: nil,
        recent_items:
          Solr.recently_updated(5)["docs"]
          |> Enum.map(&Item.from_solr(&1))
      )

    {:ok, socket}
  end

  def random_mosaic_images() do
    Enum.chunk_every(
      MosaicImages.images() |> Enum.shuffle(),
      floor(length(MosaicImages.images()) / 3)
    )
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} content_class={}>
      <div class="grid grid-flow-row auto-rows-max">
        <div class="explore-header grid-row bg-background relative">
          <div class="drop-shadow-[1px_1px_3rem_rgba(0,0,0,1)] bg-primary absolute max-h-[600px] sm:min-w-[350px] w-full lg:max-w-1/2 2xl:max-w-1/3 top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-10 p-4">
            <div class="corner-cut content-area text-center h-full w-full flex flex-col justify-evenly bg-background p-8">
              <div class="page-y-padding text-2xl flex-grow">
                {gettext(
                  "Discover %{photographs}, %{posters}, %{pamphlets}, and more to inspire your research",
                  photographs:
                    callout_link(%{
                      url: ~p"/search?#{%{filter: %{genre: "photographs"}}}",
                      label: gettext("photographs")
                    }),
                  posters:
                    callout_link(%{
                      url: ~p"/search?#{%{filter: %{genre: "posters"}}}",
                      label: gettext("posters")
                    }),
                  pamphlets:
                    callout_link(%{
                      url: ~p"/search?#{%{filter: %{genre: "pamphlets"}}}",
                      label: gettext("pamphlets")
                    })
                )
                |> Phoenix.HTML.raw()}
              </div>
              <div class="content-area bg-primary text-light-text px-0 text-2xl">
                <.primary_button href={~p"/browse"}>
                  {gettext("Explore")}
                </.primary_button>
              </div>
            </div>
          </div>
          <div
            id="hero-mosaic"
            class="h-[600px] overflow-hidden"
            phx-update="ignore"
            aria-hidden="true"
          >
            <%= for chunk <- random_mosaic_images() do %>
              <div class="h-[200px] flex items-start overflow-hidden">
                <%= for {id, image_url, item} <- chunk do %>
                  <div class="h-[200px] min-w-px flex-shrink-0">
                    <.link tabindex="-1" navigate={~p"/item/#{id}"}>
                      <img
                        class="h-full w-auto opacity-40 select-none hover:opacity-100 cursor-pointer"
                        draggable="false"
                        width={
                          (200 * item.primary_thumbnail_width / item.primary_thumbnail_height)
                          |> round
                        }
                        height="200"
                        src={image_url}
                        alt={item.title |> hd}
                      />
                    </.link>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        <.content_separator />

        <.browse_item_row
          id="recent-items"
          layout="home-content-area"
          color="bg-background"
          items={@recent_items}
          title={gettext("Recently Updated Items")}
          more_link={~p"/search?sort_by=recently_updated"}
          show_images={@show_images}
          added?={true}
        >
          <p class="my-2 font-regular">
            {gettext("Our collections are constantly growing. Discover something new!")}
          </p>
        </.browse_item_row>
      </div>
    </Layouts.app>
    """
  end

  defp callout_link(assigns) do
    Phoenix.HTML.Safe.to_iodata(~H"""
    <.link href={@url} class="text-accent font-bold" target="_blank">{@label}</.link>
    """)
  end
end

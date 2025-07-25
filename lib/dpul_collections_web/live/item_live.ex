defmodule DpulCollectionsWeb.ItemLive do
  use DpulCollections.Solr.Constants
  alias DpulCollectionsWeb.Live.Helpers
  import DpulCollectionsWeb.BrowseItem
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    {:ok, socket, layout: {DpulCollectionsWeb.Layouts, :home}}
  end

  def handle_params(params = %{"id" => id}, uri, socket) do
    item = Solr.find_by_id(id) |> Item.from_solr()
    path = URI.parse(uri).path |> URI.decode()
    # Initialize current_canvas_idx to be 0 if it's not set. 0 is a filler value
    # for "no canvas selected"
    current_canvas_idx = (params["current_canvas_idx"] || "0") |> String.to_integer()
    current_content_state_url = content_state_url(item, current_canvas_idx)

    socket =
      assign(socket,
        page_title: page_title(item, socket),
        current_canvas_idx: current_canvas_idx,
        current_content_state_url: current_content_state_url,
        display_size: false
      )

    {:noreply, build_socket(socket, item, path)}
  end

  # Redirect to the slug-ified path if we don't have it.
  defp build_socket(socket, item = %{}, path)
       when item.url != path do
    case String.starts_with?(path, item.url) do
      # We're at a sub-path, it's fine.
      true ->
        build_socket(socket, item, item.url)

      false ->
        # Replace `/item/:id` with `/i/:slug/item/:id`
        # This is regex because we should redirect if someone passed the wrong
        # slug.
        url = String.replace(path, ~r/.*\/item\/#{item.id}/, item.url)
        push_patch(socket, to: url, replace: true)
    end
  end

  defp build_socket(_, nil, _) do
    raise DpulCollectionsWeb.ItemLive.NotFoundError
  end

  defp build_socket(socket, item, _) do
    related_items =
      Solr.related_items(item, %{filter: %{"project" => item.project}})["docs"]
      |> Enum.map(&Item.from_solr(&1))

    different_project_related_items =
      Solr.related_items(item, %{filter: %{"project" => "-#{item.project}"}})["docs"]
      |> Enum.map(&Item.from_solr(&1))

    assign(socket,
      item: item,
      related_items: related_items,
      different_project_related_items: different_project_related_items
    )
  end

  attr :filter_name, :string, required: true
  attr :filter_value, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the link"

  def filter_link(assigns = %{filter_name: filter_name}) when filter_name in @filter_keys do
    ~H"""
    <.link
      class={["filter-link", @class]}
      href={~p"/search?#{%{filter: %{@filter_name => @filter_value}} |> Helpers.clean_params()}"}
      {@rest}
    >
      {@filter_value}
    </.link>
    """
  end

  def filter_link(assigns) do
    ~H"""
    {@filter_value}
    """
  end

  def render(assigns) do
    ~H"""
    <div id="item-wrap" class="grid grid-rows-[1fr/1fr] grid-cols-[1fr/1fr]">
      <.item_page {assigns} />
    </div>
    <.metadata_pane :if={@live_action == :metadata} item={@item} />
    <.viewer_pane
      :if={@live_action == :viewer}
      item={@item}
      current_canvas_idx={@current_canvas_idx}
      current_content_state_url={@current_content_state_url}
    />
    """
  end

  def item_page(assigns) do
    ~H"""
    <div class="bg-background page-y-padding content-area item-page col-start-1 row-start-1">
      <div class="column-layout my-5 flex flex-col sm:grid sm:grid-flow-row sm:auto-rows-0 sm:grid-cols-5 sm:grid-rows-[auto_1fr] sm:content-start gap-x-14 gap-y-4">
        <div class="item-title sm:row-start-1 sm:col-start-3 sm:col-span-3 h-min flex flex-col gap-4">
          <.filter_link
            class="text-xl uppercase tracking-wide"
            filter_value={@item.genre |> List.first()}
            filter_name="genre"
          />
          <h1 class="text-4xl font-bold normal-case" dir="auto">{@item.title}</h1>
          <div
            :if={!Enum.empty?(@item.transliterated_title) || !Enum.empty?(@item.alternative_title)}
            class="flex flex-col gap-2"
          >
            <p
              :for={ttitle <- @item.transliterated_title}
              dir="auto"
              class="text-2xl font-medium text-gray-500"
            >
              {ttitle}
            </p>
            <p
              :for={atitle <- @item.alternative_title}
              dir="auto"
              class="text-2xl font-medium text-gray-500"
            >
              [{atitle}]
            </p>
          </div>
          <p :if={@item.date} class="text-xl font-medium text-dark-text">{@item.date}</p>
        </div>

        <div class="thumbnails w-full sm:row-start-1 sm:col-start-1 sm:col-span-2 sm:row-span-full">
          <.primary_thumbnail item={@item} display_size={@display_size} />

          <.action_bar class="sm:hidden pt-4" item={@item} />

          <section class="image-thumbnails hidden sm:block md:col-span-2 py-4">
            <h2 class="py-1">{gettext("Images")}</h2>
            <div class="grid grid-cols-2 py-1 pr-2">
              <div class="text-left text-l text-gray-600 font-semibold">
                {gettext("%{file_min} of %{file_max} images",
                  file_min: min(@item.file_count, image_thumb_grid_count()),
                  file_max: @item.file_count
                )}
              </div>
              <div class="text-right text-accent uppercase">
                <.link
                  :if={@item.file_count > image_thumb_grid_count()}
                  patch={"#{@item.viewer_url}/1"}
                  replace
                >
                  {gettext("View all images")}
                </.link>
              </div>
            </div>
            <div class="py-1 grid grid-cols-4">
              <.thumbs
                :for={
                  {thumb, thumb_num} <-
                    Enum.with_index(Enum.take(@item.image_service_urls, image_thumb_grid_count()))
                }
                :if={@item.file_count}
                thumb={thumb}
                thumb_num={thumb_num}
                viewer_url={@item.viewer_url}
              />
            </div>
          </section>
        </div>

        <div class="metadata sm:row-start-2 sm:col-span-3 sm:col-start-3 flex flex-col gap-8">
          <div
            :for={description <- @item.description}
            dir="auto"
            class="text-xl font-medium text-dark-text font-serif"
          >
            {description}
          </div>
          <div :if={@item.project} class="text-lg font-medium text-dark-text">
            Part of <.filter_link filter_name="project" filter_value={@item.project} />
          </div>
          <.action_bar class="hidden sm:block" item={@item} />
          <.content_separator />
          <.metadata_table item={@item} />
        </div>
      </div>
      <.share_modal path={@item.url} id="share-modal" heading={gettext("Share this item")} />
    </div>
    <.browse_item_row
      :if={@item.project}
      id="related-same-project"
      items={@related_items}
      title={gettext("Similar Items in this Collection")}
      more_link={~p"/search?filter[similar]=#{@item.id}&filter[project]=#{@item.project}"}
    />
    <.browse_item_row
      :if={@item.project}
      id="related-different-project"
      items={@different_project_related_items}
      title={gettext("Similar Items outside this Collection")}
      class="grid-row bg-background"
      more_link={~p"/search?filter[similar]=#{@item.id}&filter[project]=-#{@item.project}"}
    />
    """
  end

  def metadata_pane(assigns) do
    ~H"""
    <div
      id="metadata-pane"
      class="bg-background min-w-full min-h-full translate-x-full col-start-1 row-start-1 absolute top-0"
      phx-mounted={
        JS.transition({"ease-out duration-250", "translate-x-full", "translate-x-0"})
        |> hide_covered_elements()
      }
      phx-remove={show_covered_elements()}
      data-cancel={JS.patch(@item.url, replace: true)}
      phx-window-keydown={JS.exec("data-cancel", to: "#metadata-pane")}
      phx-key="escape"
      phx-hook="ScrollTop"
    >
      <div class="header-x-padding page-y-padding bg-accent flex flex-row">
        <h1 class="uppercase text-light-text flex-auto">{gettext("Metadata")}</h1>
        <.link
          aria-label={gettext("close")}
          class="flex-none cursor-pointer justify-end"
          patch={@item.url}
          replace
        >
          <.icon class="w-8 h-8" name="hero-x-mark" />
        </.link>
      </div>
      <div class="main-content header-x-padding page-y-padding">
        <div class="py-6">
          <h2 class="sm:border-t-1 border-accent py-3">{gettext("Item Description")}</h2>
          <p dir="auto">{@item.description}</p>
        </div>
        <div
          :for={{category, fields} <- DpulCollections.Item.metadata_detail_categories()}
          class="py-6"
        >
          <div class="sm:grid sm:grid-cols-5 gap-4">
            <div class="sm:col-span-2">
              <h2 class="sm:border-t-1 border-accent py-3">{category}</h2>
            </div>
            <div class="sm:col-span-3">
              <dl>
                <.metadata_pane_row
                  :for={{field, field_label} <- fields}
                  field={field}
                  field_label={field_label}
                  value={field_value(@item, field)}
                />
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Hide elements that get covered by the viewer modal so they're not tab
  # targetable.
  def hide_covered_elements(js \\ %JS{}) do
    ["#item-wrap", ".search-bar", "footer"]
    |> Enum.reduce(js, fn selector, acc_js ->
      JS.hide(acc_js, to: selector, transition: "fade-out-scale", time: 250)
    end)
  end

  def show_covered_elements(js \\ %JS{}) do
    ["#item-wrap", ".search-bar", "footer"]
    |> Enum.reduce(js, fn selector, acc_js -> JS.show(acc_js, to: selector) end)
  end

  def viewer_pane(assigns) do
    ~H"""
    <div
      id="viewer-pane"
      class="bg-background flex flex-col min-h-full min-w-full -translate-x-full col-start-1 row-start-1 absolute top-0 dismissable"
      phx-mounted={
        JS.transition({"ease-out duration-250", "-translate-x-full", "translate-x-0"})
        |> hide_covered_elements()
      }
      phx-remove={show_covered_elements()}
      data-cancel={JS.patch(@item.url, replace: true)}
      phx-window-keydown={JS.exec("data-cancel", to: "#viewer-pane.dismissable")}
      phx-key="escape"
      phx-hook="ScrollTop"
    >
      <div class="header-x-padding page-y-padding bg-accent flex flex-row">
        <div class="flex-auto flex flex-row">
          <h1 class="uppercase text-light-text flex-none">{gettext("Viewer")}</h1>
          <.action_icon
            icon="hero-share"
            phx-click={show_viewer_share_modal()}
            variant="pane-action-icon"
            aria-label={gettext("Share")}
          >
          </.action_icon>
        </div>
        <.link
          aria-label={gettext("close")}
          class="flex-none cursor-pointer justify-end"
          patch={@item.url}
          replace
        >
          <.icon class="w-8 h-8" name="hero-x-mark" />
        </.link>
      </div>
      <!-- "relative" here lets Clover fill the full size of main-content. -->
      <!-- Ignore phoenix updates, since Clover manages switching the canvas. Without this it's jumpy on page switches. -->
      <div id="clover-viewer" class="main-content grow relative" phx-update="ignore">
        {live_react_component(
          "Components.DpulcViewer",
          [
            iiifContent: unverified_url(DpulCollectionsWeb.Endpoint, @current_content_state_url)
          ],
          id: "viewer-component"
        )}
      </div>
      <.share_modal
        path={"#{@item.viewer_url}/#{@current_canvas_idx}"}
        id="viewer-share-modal"
        heading={gettext("Share this image")}
      />
    </div>
    """
  end

  defp content_state_url(nil, _) do
    nil
  end

  defp content_state_url(item, current_canvas_idx) do
    "/iiif/#{item.id}/content_state/#{current_canvas_idx}"
  end

  defp has_dimensions(%{width: [_width | _], height: [_height | _]}), do: true
  defp has_dimensions(_), do: false

  attr :rest, :global
  attr :item, :map, required: true

  def action_bar(assigns) do
    ~H"""
    <div {@rest}>
      <div class="flex flex-row justify-left items-center">
        <.action_icon
          :if={has_dimensions(@item)}
          icon="pepicons-pencil:ruler"
          variant="item-action-icon"
          phx-click="toggle_size"
        >
          {gettext("Size")}
        </.action_icon>
        <.action_icon
          icon="hero-share"
          variant="item-action-icon"
          phx-click={JS.show(to: "#share-modal")}
        >
          {gettext("Share")}
        </.action_icon>
        <div class="ml-auto h-full flex-grow pr-4">
          <.rights_icon rights_statement={@item.rights_statement} />
        </div>
      </div>
    </div>
    """
  end

  attr :rights_statement, :any, required: true

  def rights_icon(assigns) do
    ~H"""
    <img
      class="object-fit max-h-[30px] ml-auto"
      src={~p"/images/rights/#{rights_path(@rights_statement)}"}
      alt={@rights_statement}
    />
    """
  end

  def rights_path([rights_statement | _rest]), do: rights_path(rights_statement)

  def rights_path(rights_statement) when is_binary(rights_statement) do
    rights_path =
      rights_statement
      |> String.replace(~r/[^0-9a-zA-Z ]/, "")
      |> String.replace(" ", "-")
      |> String.downcase()

    "#{rights_path}.svg"
  end

  def rights_path(_), do: ""

  attr :rest, :global
  attr :icon, :string, required: true

  attr :variant, :string,
    required: true,
    doc:
      "A variant should be defined in app.css as a tailwind utility. Variants allow rendering the icon in different sizes and with different color combinations."

  slot :inner_block, doc: "the optional inner block that renders the icon label"

  def action_icon(assigns) do
    ~H"""
    <div class="flex flex-col justify-center text-center text-sm mr-2 min-w-15 items-center">
      <button {@rest}>
        <div class={["cursor-pointer rounded-full flex justify-center items-center", @variant]}>
          <.icon class="w-full h-full" name={@icon} />
        </div>
        {render_slot(@inner_block)}
      </button>
    </div>
    """
  end

  def handle_event("toggle_size", _opts, socket = %{assigns: %{display_size: display_size}}) do
    socket =
      socket
      |> assign(display_size: !display_size)

    {:noreply, socket}
  end

  def handle_event(
        "changedCanvas",
        %{"canvas_id" => canvas_id},
        socket = %{
          assigns: %{
            current_canvas_idx: current_canvas_idx,
            item: item = %{image_canvas_ids: canvas_ids},
            live_action: :viewer
          }
        }
      )
      when not is_nil(current_canvas_idx) do
    idx = Enum.find_index(canvas_ids, fn x -> x == canvas_id end) || 0

    case idx + 1 == current_canvas_idx do
      # We're already on the correct page, don't do anything.
      true ->
        {:noreply, socket}

      # Update the URL to include the canvas number.
      false ->
        current_canvas_idx = idx + 1

        {:noreply,
         socket
         |> assign(current_canvas_idx: idx + 1)
         |> push_patch(to: "#{item.viewer_url}/#{current_canvas_idx}", replace: true)}
    end
  end

  # If we're not in the viewer, ignore this event.
  def handle_event("changedCanvas", _, socket), do: {:noreply, socket}

  def primary_thumbnail(assigns) do
    ~H"""
    <div class="grid grid-cols-[auto_minmax(0,1fr)] gap-y-2 content-start mb-2">
      <div class="primary-thumbnail col-span-2 grid grid-cols-subgrid relative">
        <div :if={@display_size} class="col-start-2 flex justify-center items-center">
          <span class="h-[11px] w-[1px] bg-accent"></span>
          <span class="h-[1px] mr-[5px] flex-grow bg-accent"></span>
          <span class="text-accent">{@item.width} cm.</span>
          <span class="h-[1px] ml-[5px] flex-grow bg-accent"></span>
          <span class="h-[11px] w-[1px] bg-accent"></span>
        </div>
        <div :if={@display_size} class="h-full flex flex-col justify-center items-center">
          <span class="w-[11px] h-[1px] bg-accent"></span>
          <span class="w-[1px] mb-[5px] flex-grow bg-accent"></span>
          <span class="text-accent pl-1 [writing-mode:vertical-rl] rotate-180">
            {@item.height} cm.
          </span>
          <span class="w-[1px] mt-[5px] flex-grow bg-accent"></span>
          <span class="w-[11px] h-[1px] bg-accent"></span>
        </div>
        <div class="col-start-2 relative">
          <.link patch={"#{@item.viewer_url}/#{primary_thumbnail_idx(@item)}"} replace>
            <img
              src={"#{@item.primary_thumbnail_service_url}/full/!#{@item.primary_thumbnail_width},#{@item.primary_thumbnail_height}/0/default.jpg"}
              alt="main image display"
              style="
              background-color: lightgray;"
              width={@item.primary_thumbnail_width}
              height={@item.primary_thumbnail_height}
            />
          </.link>
          <div
            :if={@display_size && relative_paper_dimension_style(@item)}
            id="letter-preview"
            class="absolute bottom-0 right-0 z-1 border-2 border-accent"
            style={relative_paper_dimension_style(@item)}
          >
            <div class="flex justify-center items-center z-1 w-full h-full backdrop-blur-xs bg-white/70 text-accent text-sm p-4">
              <div>
                Letter Paper 8.5" x 11" <.icon class="w-5 h-5" name="pepicons-pencil:ruler" />
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="w-full col-span-2 gap-2">
        <div class="thumbnail-buttons grid grid-cols-2 gap-2">
          <.primary_button
            id="viewer-link"
            class="left-arrow-box"
            patch={"#{@item.viewer_url}/1"}
            replace
          >
            <.icon name="hero-eye" /> {gettext("View")}
          </.primary_button>

          <.download_button item={@item} />
        </div>
      </div>
    </div>
    """
  end

  defp primary_thumbnail_idx(item) do
    (Enum.find_index(item.image_service_urls, fn x -> x == item.primary_thumbnail_service_url end) ||
       0) + 1
  end

  defp image_thumb_grid_count() do
    12
  end

  @letter_dimensions %{width: 21.59, height: 27.94}
  # Height and width are in cm.
  defp relative_paper_dimension_style(%{width: [width | _], height: [height | _]}) do
    {width, _} = Float.parse(width)
    {height, _} = Float.parse(height)
    width_percentage = @letter_dimensions.width / width * 100
    height_percentage = @letter_dimensions.height / height * 100
    # Only return a style if object is bigger than a letter.
    case {width_percentage, height_percentage} do
      {w, _} when w > 100 -> false
      {_, h} when h > 100 -> false
      _ -> "width: #{width_percentage}%; height: #{height_percentage}%;"
    end
  end

  def download_button(assigns = %{item: %{pdf_url: pdf_url}}) when is_binary(pdf_url) do
    ~H"""
    <.primary_button href={@item.pdf_url} target="_blank">
      <.icon name="hero-arrow-down-on-square" class="h-5" /><span>{gettext("Download PDF")}</span>
    </.primary_button>
    """
  end

  def download_button(assigns) do
    ~H"""
    <.primary_button disabled>
      {gettext("No PDF Available")}
    </.primary_button>
    """
  end

  # When we show the modal we need to disable "Escape" for the viewer itself, we
  # use this dismissable class for that
  def show_viewer_share_modal(js \\ %JS{}) do
    js
    |> JS.remove_class("dismissable", to: "#viewer-pane")
    |> JS.show(to: "#viewer-share-modal")
  end

  # When we hide the modal we have to re-set the copy button and make "Escape"
  # work again for dismissing the viewer pane.
  def hide_modal(id, js \\ %JS{}) do
    js
    |> JS.hide(to: "##{id}")
    |> JS.remove_class("bg-accent", to: "##{id}-value-copy")
    |> JS.add_class("dismissable", to: "#viewer-pane")
  end

  attr :id, :string, required: true
  attr :heading, :string, required: true
  attr :path, :string, required: true

  def share_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="hidden"
      phx-hook="CloseModals"
      phx-window-keydown={hide_modal(@id)}
      phx-key="escape"
    >
      <div class="fixed inset-0 p-4 flex flex-wrap justify-center items-center w-full h-full z-[1000] before:fixed before:inset-0 before:w-full before:h-full before:bg-[rgba(0,0,0,0.5)] overflow-auto">
        <div
          class="w-full max-w-2xl bg-white shadow-lg rounded-lg p-8 relative"
          phx-click-away={hide_modal(@id)}
        >
          <div class="flex items-center pb-3 border-b border-gray-300">
            <h3 class="text-xl font-semibold flex-1 text-slate-900">{@heading}</h3>
            <button aria-label="close" phx-click={hide_modal(@id)} class="cursor-pointer">
              <.icon name="hero-x-mark" />
            </button>
          </div>
          <div class="mt-4">
            <.copy_element value={"#{DpulCollectionsWeb.Endpoint.url()}#{@path}"} id={"#{@id}-value"} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def metadata_table(assigns) do
    ~H"""
    <div class="relative overflow-x-auto">
      <dl class="grid items-start gap-x-8 gap-y-4">
        <.metadata_row
          :for={{field, field_label} <- DpulCollections.Item.metadata_display_fields()}
          field_label={field_label}
          value={field_value(@item, field)}
          field={field}
        />
      </dl>
    </div>
    <.primary_button id="metadata-link" class="right-arrow-box" patch={@item.metadata_url} replace>
      <.icon name="hero-table-cells" />{gettext("View all metadata for this item")}
    </.primary_button>
    """
  end

  def metadata_row(%{value: []} = assigns) do
    ~H"""
    """
  end

  def metadata_row(assigns) do
    ~H"""
    <div class="col-span-2 grid grid-cols-subgrid border-b-1 border-accent pb-4">
      <dt class="font-bold text-lg">
        {@field_label}
      </dt>
      <dd :for={value <- @value} dir="auto" class="col-start-2">
        <.filter_link filter_value={value} filter_name={"#{@field}"} />
      </dd>
    </div>
    """
  end

  def metadata_pane_row(%{value: []} = assigns) do
    ~H"""
    """
  end

  # manifest url copy element has to become single-column at smaller sizes
  def metadata_pane_row(assigns = %{field: :iiif_manifest_url}) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 border-t-1 border-accent py-3">
      <dt class="font-bold text-lg">
        {@field_label}
      </dt>
      <dd :for={value <- @value} class="py-1">
        {value}
      </dd>
    </div>
    """
  end

  def metadata_pane_row(assigns) do
    ~H"""
    <div class="grid grid-cols-2 border-t-1 border-accent py-3">
      <dt class="font-bold text-lg">
        {@field_label}
      </dt>
      <dd :for={value <- @value} dir="auto" class="col-start-2 py-1">
        <.filter_link filter_value={value} filter_name={"#{@field}"} />
      </dd>
    </div>
    """
  end

  def field_value(item, field = :iiif_manifest_url) do
    value = Kernel.get_in(item, [Access.key(field)])

    copy_element(%{value: value, id: "iiif-url"})
    |> List.wrap()
  end

  def field_value(item, field) do
    item
    |> Kernel.get_in([Access.key(field)])
    |> List.wrap()
  end

  attr :value, :string, required: true, doc: "the value to copy"

  attr :id, :string,
    required: true,
    doc:
      "text <p> id for click to use in identifying text to copy. internal to this component, but should be unique"

  def copy_element(assigns) do
    ~H"""
    <div class="rounded-lg border border-gray-300 grid grid-rows-1 grid-cols-5 relative">
      <p id={@id} class="text-sm text-slate-600 m-2 wrap-anywhere col-span-4">
        {@value}
      </p>
      <button
        id={"#{@id}-copy"}
        phx-click={JS.dispatch("dpulc:clipcopy", to: "##{@id}") |> JS.add_class("bg-accent")}
        class="group btn-primary px-4 py-3 text-sm font-medium h-full"
      >
        <span class="group-[.bg-accent]:hidden">Copy</span>
        <span class="not-group-[.bg-accent]:hidden">Copied</span>
      </button>
    </div>
    """
  end

  def thumbs(assigns) do
    ~H"""
    <div class="pr-2 pb-2">
      <.link patch={"#{@viewer_url}/#{@thumb_num + 1}"}>
        <img
          class="h-full w-full object-cover"
          src={"#{@thumb}/full/350,465/0/default.jpg"}
          alt={"image #{@thumb_num}"}
          style="
            background-color: lightgray;"
        />
      </.link>
    </div>
    """
  end

  defp page_title(nil, _), do: nil

  defp page_title(item, socket) do
    case socket.assigns.live_action do
      :metadata -> "Metadata - #{item.title} - Digital Collections"
      :viewer -> "Viewer - #{item.title} - Digital Collections"
      _ -> "#{item.title} - Digital Collections"
    end
  end
end

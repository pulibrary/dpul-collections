defmodule DpulCollectionsWeb.MetadataLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    {:ok, socket, layout: {DpulCollectionsWeb.Layouts, :home}}
  end

  def handle_params(%{"id" => id}, uri, socket) do
    item = Solr.find_by_id(id) |> Item.from_solr()
    path = URI.parse(uri).path |> URI.decode()
    {:noreply, build_socket(socket, item, path)}
  end

  defp build_socket(socket, item, path) when item.metadata_url != path do
    push_patch(socket, to: item.metadata_url, replace: true)
  end

  defp build_socket(_, nil, _) do
    raise DpulCollectionsWeb.ItemLive.NotFoundError
  end

  defp build_socket(socket, item, _) do
    assign(socket, item: item)
  end

  def render(assigns) do
    ~H"""
    <div class="header-x-padding page-y-padding bg-accent flex flex-row">
      <h1 class="uppercase text-light-text flex-auto">{gettext("Metadata")}</h1>
      <button class="flex-none cursor-pointer justify-end">
        <.link id="back-link" navigate={~p"/item/#{@item.id}"}>
          <.icon class="w-8 h-8" name="hero-x-mark" />
        </.link>
      </button>
    </div>
    <div class="main-content header-x-padding page-y-padding">
      <div class="py-6">
        <h2 class="sm:border-t-1 border-accent py-3">{gettext("Item Description")}</h2>
        <p>{@item.description}</p>
      </div>
      <div :for={{category, fields} <- DpulCollections.Item.metadata_detail_categories()} class="py-6">
        <div class="sm:grid sm:grid-cols-5 gap-4">
          <div class="sm:col-span-2">
            <h2 class="sm:border-t-1 border-accent py-3">{category}</h2>
          </div>
          <div class="sm:col-span-3">
            <dl>
              <.metadata_pane_row
                :for={{field, field_label} <- fields}
                field_label={field_label}
                value={field_value(@item, field)}
              />
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def metadata_pane_row(%{value: []} = assigns) do
    ~H"""
    """
  end

  def metadata_pane_row(assigns) do
    ~H"""
    <div class="grid grid-cols-2 border-t-1 border-accent py-3">
      <dt class="font-bold text-lg">
        {@field_label}
      </dt>
      <dd :for={value <- @value} class="col-start-2 py-1">
        {value}
      </dd>
    </div>
    """
  end

  def field_value(item, field) do
    item
    |> Kernel.get_in([Access.key(field)])
    |> List.wrap()
  end
end

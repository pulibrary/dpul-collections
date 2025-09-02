defmodule DpulCollectionsWeb.ContentWarnings do
  use DpulCollectionsWeb, :html
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: DpulCollectionsWeb.Gettext

  defmacro __using__(_) do
    quote do
      on_mount DpulCollectionsWeb.ContentWarnings
      # Add a way to handle the show_images event to all live views.
      def handle_event(
            "show_images",
            %{"id" => id},
            socket = %{assigns: %{show_images: show_images}}
          ) do
        new_show_images =
          case show_images do
            nil -> [id]
            _ -> [id | show_images]
          end

        {:noreply, socket |> assign(show_images: new_show_images)}
      end
    end
  end

  # All our liveviews could display show_images, so set it.
  def on_mount(:default, _params, %{"show_images" => show_images}, socket) do
    {:cont, assign(socket, :show_images, show_images)}
  end

  def on_mount(:default, _params, _, socket) do
    {:cont, assign(socket, :show_images, [])}
  end

  attr :item_id, :string, required: true
  attr :content_warning, :string, required: true

  def show_images_banner(assigns) do
    ~H"""
    <div
      id={"show-image-banner-#{@item_id}"}
      class="show-image-banner absolute top-0 left-0 w-full p-3 bg-white z-1 flex gap-2 align-center"
    >
      <.link
        id={"open-show-image-banner-#{@item_id}"}
        class="flex gap-2 align-center text-rust"
        phx-click={JS.exec("phx-open", to: "#show-image-banner-#{@item_id}-dialog")}
      >
        <span class="flex-none">
          <.icon name="hero-eye-slash" class="h-5 w-5 icon mb-[2px]" />
        </span>
        <span>
          {gettext("Why are the images blurred?")}
        </span>
      </.link>
    </div>
    <.content_modal {assigns} />
    """
  end

  def content_modal(assigns) do
    # aria-labelledby={"show-image-modal-#{@item_id}-title"}
    ~H"""
    <.modal id={"show-image-banner-#{@item_id}-dialog"}>
      <!-- Modal header -->
      <div class="flex items-center justify-between p-6 pb-0 rounded-t">
        <h2 id={"show-image-modal-#{@item_id}-title"} class="text-3xl font-semibold">
          Content Warning
        </h2>
        <button
          id={"show-image-banner-close-button-#{@item_id}"}
          type="button"
          class="bg-transparent hover:bg-gray-200 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center dark:hover:bg-gray-600 dark:hover:text-white"
          phx-click={JS.exec("phx-close", to: {:closest, "dialog"})}
        >
          <svg
            class="w-3 h-3"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 14 14"
          >
            <path
              stroke="currentColor"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"
            />
          </svg>
          <span class="sr-only">{gettext("Close modal")}</span>
        </button>
      </div>
      <.content_warning_body {assigns} />
    </.modal>
    """
  end

  def responsible_collection_link(assigns) do
    ~H"""
    <.link
      href="https://library.princeton.edu/about/responsible-collection-description"
      class="text-accent"
      target="_blank"
    >
      {gettext("Responsible Collection Description")}
    </.link>
    """
  end

  attr :item_id, :string, required: true
  attr :content_warning, :string, required: true

  def content_warning_body(assigns) do
    ~H"""
    <div class="p-6 space-y-4">
      <h3 class="font-2xl font-semibold">{@content_warning}</h3>
      <p>
        {gettext(
          "Images are blurred because this item has been determined to contain images with sensitive content. To view the content in this item, click View Content below."
        )}
      </p>
      <p>
        {gettext(
          "For more information, please see the PUL statement on %{responsible_collection_link}.",
          responsible_collection_link:
            responsible_collection_link(%{}) |> Phoenix.HTML.Safe.to_iodata() |> to_string()
        )
        |> raw}
      </p>
    </div>
    <!-- Modal footer -->
    <div class="flex items-center p-6 pt-0 rounded-b dark:border-gray-600">
      <.primary_button
        id={"show-images-#{@item_id}"}
        data-id={@item_id}
        phx-click={
          JS.dispatch("dpulc:showImages")
          |> JS.push("show_images", value: %{id: @item_id})
        }
      >
        {gettext("View content")}
      </.primary_button>
    </div>
    """
  end
end

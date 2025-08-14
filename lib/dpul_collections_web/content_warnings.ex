defmodule DpulCollectionsWeb.ContentWarnings do
  use DpulCollectionsWeb, :html
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: DpulCollectionsWeb.Gettext

  defmacro __using__(_) do
    quote do
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
        data-dialog-id={"show-image-banner-#{@item_id}-dialog"}
        phx-hook="OpenDialogHook"
      >
        <span class="flex-none">
          <.icon name="hero-eye-slash" class="h-5 w-5 icon mb-[2px]" />
        </span>
        <span>
          Why are the images blurred?
        </span>
      </.link>
      <!-- Modal content -->
      <dialog
        id={"show-image-banner-#{@item_id}-dialog"}
        class="max-w-2xl backdrop:bg-black/50 open:top-[50%] open:left-[50%] open:-translate-x-50 open:-translate-y-50 fixed bg-white rounded-lg shadow-sm text-dark-text"
        aria-labelledby={"show-image-modal-#{@item_id}-title"}
        closedBy="any"
      >
        <!-- Modal header -->
        <div class="flex items-center justify-between p-6 pb-0 rounded-t">
          <h2 id={"show-image-modal-#{@item_id}-title"} class="text-3xl font-semibold">
            Content Warning
          </h2>
          <button
            id={"show-image-banner-close-button-#{@item_id}"}
            type="button"
            class="bg-transparent hover:bg-gray-200 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center dark:hover:bg-gray-600 dark:hover:text-white"
            data-dialog-id={"show-image-banner-#{@item_id}-dialog"}
            phx-hook="CloseDialogHook"
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
            <span class="sr-only">Close modal</span>
          </button>
        </div>
        <.content_warning_body {assigns} />
      </dialog>
    </div>
    """
  end

  attr :item_id, :string, required: true
  attr :content_warning, :string, required: true

  def content_warning_body(assigns) do
    ~H"""
    <div class="p-6 space-y-4">
      <h3 class="font-2xl font-semibold">{@content_warning}</h3>
      <p>
        Images are blurred because this item has been determined to contain images with sensitive content. To view the content in this item, click View Content below.
      </p>
      <p>
        For more information, please see the PUL statement on <.link
          href="https://library.princeton.edu/about/responsible-collection-description"
          class="text-accent"
          target="_blank"
        >Responsible Collection Description</.link>.
      </p>
    </div>
    <!-- Modal footer -->
    <div class="flex items-center p-6 pt-0 rounded-b dark:border-gray-600">
      <.primary_button
        id={"show-images-#{@item_id}"}
        phx-click={
          JS.dispatch("dpulc:showImages")
          |> JS.push("show_images", value: %{id: @item_id})
        }
        data-id={@item_id}
        data-dialog-id={"show-image-banner-#{@item_id}-dialog"}
      >
        {gettext("View content")}
      </.primary_button>
    </div>
    """
  end
end

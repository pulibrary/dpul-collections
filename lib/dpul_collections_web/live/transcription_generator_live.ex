defmodule DpulCollectionsWeb.TranscriptionGeneratorLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        transcribe_form:
          to_form(%{
            "url" => nil
          }),
        transcription_urls: %{}
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} content_class={} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto py-8 px-4">
        <div class="bg-white shadow-sm border border-gray-200 p-6 mb-8">
          <h1 class="text-lg font-semibold mb-4">Transcription Generator</h1>
          <.form
            id="transcribe-form"
            for={@transcribe_form}
            class="flex flex-col md:flex-row gap-4 items-end"
            phx-submit="transcribe"
          >
            <div class="w-full">
              <.input
                type="text"
                class="text-sm"
                label="IIIF URL"
                placeholder="https://..."
                field={@transcribe_form[:url]}
              />
            </div>
            <.primary_button class="w-full md:w-auto whitespace-nowrap">
              Generate
            </.primary_button>
          </.form>
        </div>

        <div :if={Enum.any?(@transcription_urls)} class="space-y-4">
          <h2 class="text-sm font-semibold uppercase tracking-wider">
            Queue & Results
          </h2>

          <.translation_queue_entry
            :for={{{url, link}, idx} <- Enum.with_index(@transcription_urls)}
            link={link}
            url={url}
            idx={idx}
            class="bg-white border border-gray-200 shadow-sm overflow-hidden"
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp processing_status(assigns = %{link: nil}) do
    ~H"""
    <span class="inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-800 ring-1 ring-inset ring-yellow-600/20 animate-pulse">
      Processing...
    </span>
    """
  end

  defp processing_status(assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
      Done
    </span>
    """
  end

  def translation_queue_entry(assigns) do
    ~H"""
    <div class={@class}>
      <div class="bg-gray-50 px-4 py-2 border-b border-gray-100 flex items-center justify-between">
        <span class="text-xs font-bold uppercase">Source</span>
        <.processing_status link={@link} />
      </div>

      <div class="p-4 space-y-3">
        <div
          class="text-xs truncate bg-gray-50 p-2 rounded border border-gray-100"
          title={@url}
        >
          {@url}
        </div>

        <div>
          <.copy_element
            value={@link}
            id={"transcription#{@idx}value"}
          />
        </div>
      </div>
    </div>
    """
  end

  def copy_element(assigns = %{value: nil}) do
    ~H"""
    <div class="h-12 w-full bg-gray-100 rounded animate-pulse flex items-center justify-center text-xs">
      Generating Transcription...
    </div>
    """
  end

  def copy_element(assigns) do
    ~H"""
    <div class="rounded-lg border border-gray-300 grid grid-rows-1 grid-cols-1 md:grid-cols-5 relative overflow-hidden bg-white">
      <p
        id={@id}
        class="text-sm text-slate-600 m-2 truncate col-span-4 self-center"
        title={@value}
      >
        {@value}
      </p>
      <button
        id={"#{@id}-copy"}
        phx-click={JS.dispatch("dpulc:clipcopy", to: "##{@id}") |> JS.add_class("bg-accent")}
        class="group btn-primary px-4 py-2 text-sm font-medium h-full w-full flex items-center justify-center"
      >
        <span class="group-[.bg-accent]:hidden">{gettext("Copy")}</span>
        <span class="not-group-[.bg-accent]:hidden">{gettext("Copied")}</span>
      </button>
    </div>
    """
  end

  def handle_event("transcribe", %{"url" => url}, socket) do
    Task.Supervisor.async_nolink(
      DpulCollections.TaskSupervisor,
      fn ->
        {url, DpulCollections.Transcription.get_viewer_url(url)}
      end
    )

    socket =
      socket
      |> assign(
        transcribe_form:
          to_form(%{
            "url" => nil
          }),
        transcription_urls: socket.assigns.transcription_urls |> Map.put(url, nil)
      )

    {:noreply, socket}
  end

  def handle_info({ref, {url, link}}, socket) do
    Process.demonitor(ref, [:flush])

    socket =
      socket
      |> assign(transcription_urls: socket.assigns.transcription_urls |> Map.put(url, link))

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, _, _, reason}, socket) do
    dbg(reason)
    {:noreply, socket}
  end
end

defmodule DpulCollectionsWeb.TranscriptionGeneratorLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollections.Transcription

  def mount(_params, _session, socket) do
    default_model = Transcription.default_model()
    default_thinking = Transcription.default_thinking_level()

    socket =
      socket
      |> assign(
        transcribe_form:
          to_form(%{
            "url" => nil,
            "transcribe_model" => default_model,
            "bbox_model" => default_model,
            "transcribe_thinking" => default_thinking,
            "bbox_thinking" => default_thinking
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
            class="flex flex-col gap-4"
            phx-submit="transcribe"
          >
            <div class="flex flex-col md:flex-row gap-4 items-end">
              <div class="w-full">
                <.input
                  type="text"
                  class="text-sm"
                  label="IIIF URL"
                  placeholder="https://..."
                  field={@transcribe_form[:url]}
                />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <.input
                  type="select"
                  label="Transcription Model (Step 1)"
                  field={@transcribe_form[:transcribe_model]}
                  options={Transcription.model_options()}
                />
              </div>
              <div>
                <.input
                  type="select"
                  label="Transcription Thinking Level"
                  field={@transcribe_form[:transcribe_thinking]}
                  options={Transcription.thinking_level_options()}
                />
              </div>
              <div>
                <.input
                  type="select"
                  label="Bounding Box Model (Step 2)"
                  field={@transcribe_form[:bbox_model]}
                  options={Transcription.model_options()}
                />
              </div>
              <div>
                <.input
                  type="select"
                  label="Bounding Box Thinking Level"
                  field={@transcribe_form[:bbox_thinking]}
                  options={Transcription.thinking_level_options()}
                />
              </div>
            </div>

            <div class="flex justify-end">
              <.primary_button class="w-full md:w-auto whitespace-nowrap">
                Generate
              </.primary_button>
            </div>
          </.form>
        </div>

        <div :if={Enum.any?(@transcription_urls)} class="space-y-4">
          <h2 class="text-sm font-semibold uppercase tracking-wider">
            Queue & Results
          </h2>

          <.translation_queue_entry
            :for={{{_ref, info}, idx} <- Enum.sort_by(@transcription_urls, fn {_, i} -> i.start end, :desc) |> Enum.with_index()}
            link={info.link}
            duration={info.duration}
            transcribe_model={info.transcribe_model}
            bbox_model={info.bbox_model}
            transcribe_thinking={info.transcribe_thinking}
            bbox_thinking={info.bbox_thinking}
            usage={info.usage}
            cost={info.cost}
            url={info.url}
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
    <div class="flex items-center gap-2">
      <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
        Done ({@duration}s)
      </span>
      <span class="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-600/20">
        ${:erlang.float_to_binary(@cost, decimals: 4)}
      </span>
    </div>
    """
  end

  def translation_queue_entry(assigns) do
    ~H"""
    <div class={@class}>
      <div class="bg-gray-50 px-4 py-2 border-b border-gray-100 flex items-center justify-between">
        <div class="flex flex-col gap-1">
          <span class="text-xs font-bold uppercase">Models & Thinking</span>
          <div class="flex items-center gap-1 text-[0.65rem] text-gray-500 font-mono">
            <span title="Transcription Model">{@transcribe_model}</span>
            <span class="text-gray-400">({@transcribe_thinking})</span>
            <span>&rarr;</span>
            <span title="Bounding Box Model">{@bbox_model}</span>
            <span class="text-gray-400">({@bbox_thinking})</span>
          </div>
          <div :if={@usage} class="text-[0.65rem] text-gray-500">
            Tokens: {format_number(@usage.total_tokens)} ({format_number(@usage.input_tokens)} in / {format_number(@usage.output_tokens)} out)
          </div>
        </div>
        <.processing_status link={@link} duration={@duration} cost={@cost || 0.0} />
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

  def handle_event(
        "transcribe",
        %{
          "url" => url,
          "transcribe_model" => tm,
          "bbox_model" => bm,
          "transcribe_thinking" => tt,
          "bbox_thinking" => bt
        },
        socket
      ) do
    task =
      Task.Supervisor.async_nolink(
        DpulCollections.TaskSupervisor,
        fn ->
          opts = [transcribe_thinking: tt, bbox_thinking: bt]
          {url, DpulCollections.Transcription.get_viewer_url(url, tm, bm, opts)}
        end
      )

    info = %{
      url: url,
      transcribe_model: tm,
      bbox_model: bm,
      transcribe_thinking: tt,
      bbox_thinking: bt,
      link: nil,
      usage: nil,
      cost: nil,
      start: System.monotonic_time(:millisecond),
      duration: nil
    }

    socket =
      socket
      |> assign(
        transcribe_form:
          to_form(%{
            "url" => nil,
            "transcribe_model" => tm,
            "bbox_model" => bm,
            "transcribe_thinking" => tt,
            "bbox_thinking" => bt
          }),
        transcription_urls: Map.put(socket.assigns.transcription_urls, task.ref, info)
      )

    {:noreply, socket}
  end

  def handle_info({ref, {_url, {link, usage, cost}}}, socket) do
    Process.demonitor(ref, [:flush])

    # Lookup by Task Reference
    if info = socket.assigns.transcription_urls[ref] do
      end_time = System.monotonic_time(:millisecond)
      duration = Float.round((end_time - info.start) / 1000, 2)

      new_info =
        Map.merge(info, %{
          link: link,
          usage: usage,
          cost: cost.total,
          duration: duration
        })

      socket =
        socket
        |> assign(transcription_urls: Map.put(socket.assigns.transcription_urls, ref, new_info))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, _ref, _, _, reason}, socket) do
    dbg(reason)
    {:noreply, socket}
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_number(_), do: "0"
end

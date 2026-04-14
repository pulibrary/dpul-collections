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
            "bbox_thinking" => default_thinking,
            "step_1_prompt" => Transcription.default_step_1_prompt(),
            "step_2_prompt" => Transcription.default_step_2_prompt()
          }),
        transcription_urls: %{},
        mode: "single",
        manifest_url: "",
        manifest_label: nil,
        canvases: [],
        selected_canvases: MapSet.new(),
        manifest_results: %{},
        manifest_processing: false
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} content_class={} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto py-8 px-4">
        <div class="bg-white shadow-sm border border-gray-200 p-6 mb-8">
          <h1 class="text-lg font-semibold mb-4">Transcription Generator</h1>

          <div class="flex gap-2 mb-4">
            <button
              type="button"
              phx-click="set_mode"
              phx-value-mode="single"
              class={"px-3 py-1.5 text-sm font-medium rounded-md #{if @mode == "single", do: "bg-brand text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              Single Image
            </button>
            <button
              type="button"
              phx-click="set_mode"
              phx-value-mode="manifest"
              class={"px-3 py-1.5 text-sm font-medium rounded-md #{if @mode == "manifest", do: "bg-brand text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              IIIF Manifest
            </button>
          </div>

          <%= if @mode == "single" do %>
            <.single_image_form transcribe_form={@transcribe_form} />
          <% else %>
            <.manifest_form
              transcribe_form={@transcribe_form}
              manifest_url={@manifest_url}
              manifest_label={@manifest_label}
              canvases={@canvases}
              selected_canvases={@selected_canvases}
              manifest_results={@manifest_results}
              manifest_processing={@manifest_processing}
            />
          <% end %>
        </div>

        <%= if @mode == "manifest" && @manifest_label && all_manifest_done?(@selected_canvases, @manifest_results) do %>
          <.manifest_markdown_output
            manifest_label={@manifest_label}
            canvases={@canvases}
            selected_canvases={@selected_canvases}
            manifest_results={@manifest_results}
          />
        <% end %>

        <div :if={@mode == "single" && Enum.any?(@transcription_urls)} class="space-y-4">
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

  defp single_image_form(assigns) do
    ~H"""
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
            label="IIIF Image URL"
            placeholder="https://..."
            field={@transcribe_form[:url]}
          />
        </div>
      </div>

      <.model_and_prompt_fields transcribe_form={@transcribe_form} />

      <div class="flex justify-end">
        <.primary_button class="w-full md:w-auto whitespace-nowrap">
          Generate
        </.primary_button>
      </div>
    </.form>
    """
  end

  defp manifest_form(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <form phx-submit="fetch_manifest" class="flex flex-col md:flex-row gap-2 items-end">
        <div class="w-full">
          <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">Manifest URL</label>
          <input
            type="text"
            name="manifest_url"
            value={@manifest_url}
            placeholder="https://figgy.princeton.edu/.../manifest"
            class="block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-400"
          />
        </div>
        <button type="submit" class="btn-primary px-4 py-2 text-sm font-medium whitespace-nowrap rounded-lg">
          Fetch Canvases
        </button>
      </form>

      <%= if @manifest_label do %>
        <div class="border border-gray-200 rounded-lg overflow-hidden">
          <div class="bg-gray-50 px-4 py-2 border-b border-gray-100 flex items-center justify-between">
            <div>
              <h3 class="text-sm font-semibold">{@manifest_label}</h3>
              <p class="text-xs text-gray-500">{length(@canvases)} canvases</p>
            </div>
            <div class="flex gap-2">
              <button type="button" phx-click="select_all" class="text-xs text-blue-600 hover:underline">Select All</button>
              <button type="button" phx-click="deselect_all" class="text-xs text-blue-600 hover:underline">Deselect All</button>
            </div>
          </div>

          <div class="max-h-64 overflow-y-auto divide-y divide-gray-100">
            <label
              :for={{canvas, idx} <- Enum.with_index(@canvases)}
              class={"flex items-center gap-3 px-4 py-2 cursor-pointer hover:bg-gray-50 #{canvas_status_class(canvas.id, @manifest_results)}"}
            >
              <input
                type="checkbox"
                checked={MapSet.member?(@selected_canvases, canvas.id)}
                phx-click="toggle_canvas"
                phx-value-id={canvas.id}
                class="rounded border-gray-300 text-brand focus:ring-brand"
              />
              <span class="text-sm flex-1">{canvas.label}</span>
              <.canvas_status_badge id={canvas.id} manifest_results={@manifest_results} />
            </label>
          </div>
        </div>

        <.form
          id="manifest-settings-form"
          for={@transcribe_form}
          class="flex flex-col gap-4"
          phx-submit="run_manifest_ocr"
        >
          <.model_and_prompt_fields transcribe_form={@transcribe_form} />

          <div class="flex items-center justify-between">
            <p class="text-sm text-gray-500">
              {MapSet.size(@selected_canvases)} pages selected
              <%= if manifest_progress(@selected_canvases, @manifest_results) do %>
                — {manifest_progress(@selected_canvases, @manifest_results)}
              <% end %>
            </p>
            <.primary_button
              class="w-full md:w-auto whitespace-nowrap"
              disabled={MapSet.size(@selected_canvases) == 0 || @manifest_processing}
            >
              <%= if @manifest_processing do %>
                Processing...
              <% else %>
                Run OCR on Selected
              <% end %>
            </.primary_button>
          </div>
        </.form>
      <% end %>
    </div>
    """
  end

  defp model_and_prompt_fields(assigns) do
    ~H"""
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

    <details class="border border-gray-200 rounded-lg">
      <summary class="px-4 py-2 cursor-pointer text-sm font-medium text-gray-700 hover:bg-gray-50">
        Customize Prompts
      </summary>
      <div class="p-4 space-y-4 border-t border-gray-200">
        <div>
          <.input
            type="textarea"
            label="Step 1: Transcription Prompt"
            field={@transcribe_form[:step_1_prompt]}
            rows="12"
            class="font-mono text-xs"
          />
        </div>
        <div>
          <.input
            type="textarea"
            label="Step 2: Bounding Box Prompt (use {{CONTENT_JSON}} as placeholder)"
            field={@transcribe_form[:step_2_prompt]}
            rows="10"
            class="font-mono text-xs"
          />
        </div>
      </div>
    </details>
    """
  end

  defp canvas_status_badge(%{manifest_results: results, id: id} = assigns) do
    assigns = assign(assigns, :status, Map.get(results, id))

    ~H"""
    <span
      :if={@status && @status.status == :processing}
      class="inline-flex items-center rounded-md bg-yellow-50 px-2 py-0.5 text-xs font-medium text-yellow-800 ring-1 ring-inset ring-yellow-600/20 animate-pulse"
    >
      Processing...
    </span>
    <span
      :if={@status && @status.status == :done}
      class="inline-flex items-center rounded-md bg-green-50 px-2 py-0.5 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"
    >
      Done
    </span>
    <span
      :if={@status && @status.status == :error}
      class="inline-flex items-center rounded-md bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/20"
    >
      Error
    </span>
    """
  end

  defp canvas_status_class(canvas_id, manifest_results) do
    case Map.get(manifest_results, canvas_id) do
      %{status: :done} -> "bg-green-50/50"
      %{status: :processing} -> "bg-yellow-50/50"
      %{status: :error} -> "bg-red-50/50"
      _ -> ""
    end
  end

  defp manifest_progress(selected_canvases, manifest_results) do
    total = MapSet.size(selected_canvases)

    if total == 0 do
      nil
    else
      done =
        selected_canvases
        |> Enum.count(fn id ->
          case Map.get(manifest_results, id) do
            %{status: :done} -> true
            %{status: :error} -> true
            _ -> false
          end
        end)

      if done > 0, do: "#{done}/#{total} complete", else: nil
    end
  end

  defp all_manifest_done?(selected_canvases, manifest_results) do
    MapSet.size(selected_canvases) > 0 &&
      Enum.all?(selected_canvases, fn id ->
        case Map.get(manifest_results, id) do
          %{status: :done} -> true
          %{status: :error} -> true
          _ -> false
        end
      end)
  end

  defp manifest_markdown_output(assigns) do
    markdown = build_manifest_markdown(assigns.manifest_label, assigns.canvases, assigns.selected_canvases, assigns.manifest_results)
    assigns = assign(assigns, :markdown, markdown)

    ~H"""
    <div class="bg-white shadow-sm border border-gray-200 p-6 mb-8">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold">Markdown Output</h2>
        <button
          id="copy-markdown-btn"
          phx-click={JS.dispatch("dpulc:clipcopy", to: "#manifest-markdown-output") |> JS.add_class("bg-accent")}
          class="group btn-primary px-4 py-2 text-sm font-medium rounded-lg"
        >
          <span class="group-[.bg-accent]:hidden">Copy Markdown</span>
          <span class="not-group-[.bg-accent]:hidden">Copied!</span>
        </button>
      </div>
      <pre
        id="manifest-markdown-output"
        class="bg-gray-50 border border-gray-200 rounded-lg p-4 text-sm font-mono whitespace-pre-wrap overflow-x-auto max-h-96 overflow-y-auto"
      >{@markdown}</pre>
    </div>
    """
  end

  defp build_manifest_markdown(manifest_label, canvases, selected_canvases, manifest_results) do
    header = "# #{manifest_label}\n\n"

    links =
      canvases
      |> Enum.filter(fn c -> MapSet.member?(selected_canvases, c.id) end)
      |> Enum.map(fn canvas ->
        case Map.get(manifest_results, canvas.id) do
          %{status: :done, viewer_link: link} ->
            "- [#{canvas.label}](#{link})"

          %{status: :error, error: error} ->
            "- #{canvas.label} — Error: #{error}"

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    header <> links
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

  # Event Handlers

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: mode)}
  end

  def handle_event("fetch_manifest", %{"manifest_url" => url}, socket) do
    case Transcription.fetch_manifest(url) do
      {:ok, label, canvases} ->
        {:noreply,
         assign(socket,
           manifest_url: url,
           manifest_label: label,
           canvases: canvases,
           selected_canvases: MapSet.new(Enum.map(canvases, & &1.id)),
           manifest_results: %{}
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to fetch manifest: #{reason}")}
    end
  end

  def handle_event("toggle_canvas", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_canvases, id) do
        MapSet.delete(socket.assigns.selected_canvases, id)
      else
        MapSet.put(socket.assigns.selected_canvases, id)
      end

    {:noreply, assign(socket, selected_canvases: selected)}
  end

  def handle_event("select_all", _, socket) do
    {:noreply, assign(socket, selected_canvases: MapSet.new(Enum.map(socket.assigns.canvases, & &1.id)))}
  end

  def handle_event("deselect_all", _, socket) do
    {:noreply, assign(socket, selected_canvases: MapSet.new())}
  end

  def handle_event(
        "run_manifest_ocr",
        %{
          "transcribe_model" => tm,
          "bbox_model" => bm,
          "transcribe_thinking" => tt,
          "bbox_thinking" => bt,
          "step_1_prompt" => s1p,
          "step_2_prompt" => s2p
        },
        socket
      ) do
    selected = socket.assigns.selected_canvases
    canvases = socket.assigns.canvases

    # Initialize manifest_results — always re-process selected canvases
    initial_results =
      canvases
      |> Enum.filter(fn c -> MapSet.member?(selected, c.id) end)
      |> Enum.reduce(socket.assigns.manifest_results, fn canvas, acc ->
        Map.put(acc, canvas.id, %{status: :processing, viewer_link: nil, error: nil})
      end)

    # Spawn tasks for all selected canvases
    canvases
    |> Enum.filter(fn c -> MapSet.member?(selected, c.id) end)
    |> Enum.each(fn canvas ->
      Task.Supervisor.async_nolink(
        DpulCollections.TaskSupervisor,
        fn ->
          opts = [
            transcribe_thinking: tt,
            bbox_thinking: bt,
            step_1_prompt: s1p,
            step_2_prompt: s2p
          ]

          result = Transcription.get_viewer_url(canvas.image_service_url, tm, bm, opts)
          {:manifest_page, canvas.id, result}
        end
      )
    end)

    {:noreply,
     assign(socket,
       manifest_results: initial_results,
       manifest_processing: true,
       transcribe_form:
         to_form(%{
           "transcribe_model" => tm,
           "bbox_model" => bm,
           "transcribe_thinking" => tt,
           "bbox_thinking" => bt,
           "step_1_prompt" => s1p,
           "step_2_prompt" => s2p
         })
     )}
  end

  def handle_event(
        "transcribe",
        %{
          "url" => url,
          "transcribe_model" => tm,
          "bbox_model" => bm,
          "transcribe_thinking" => tt,
          "bbox_thinking" => bt,
          "step_1_prompt" => s1p,
          "step_2_prompt" => s2p
        },
        socket
      ) do
    url =
      cond do
        String.ends_with?(url, "default.jpg") ->
          String.split(String.reverse(url), "/", parts: 5) |> Enum.at(-1) |> String.reverse()

        true ->
          url
      end

    task =
      Task.Supervisor.async_nolink(
        DpulCollections.TaskSupervisor,
        fn ->
          opts = [
            transcribe_thinking: tt,
            bbox_thinking: bt,
            step_1_prompt: s1p,
            step_2_prompt: s2p
          ]

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
            "bbox_thinking" => bt,
            "step_1_prompt" => s1p,
            "step_2_prompt" => s2p
          }),
        transcription_urls: Map.put(socket.assigns.transcription_urls, task.ref, info)
      )

    {:noreply, socket}
  end

  # Handle manifest page completion
  def handle_info({ref, {:manifest_page, canvas_id, {link, _usage, _cost}}}, socket) do
    Process.demonitor(ref, [:flush])

    manifest_results =
      Map.put(socket.assigns.manifest_results, canvas_id, %{
        status: :done,
        viewer_link: link,
        error: nil
      })

    processing =
      not all_manifest_done?(socket.assigns.selected_canvases, manifest_results)

    {:noreply, assign(socket, manifest_results: manifest_results, manifest_processing: processing)}
  end

  # Handle single image completion
  def handle_info({ref, {_url, {link, usage, cost}}}, socket) do
    Process.demonitor(ref, [:flush])

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
    # Check if this is a manifest task that failed
    failed_canvas =
      socket.assigns.manifest_results
      |> Enum.find(fn {_id, info} -> info.status == :processing end)

    socket =
      case failed_canvas do
        {canvas_id, _} ->
          manifest_results =
            Map.put(socket.assigns.manifest_results, canvas_id, %{
              status: :error,
              viewer_link: nil,
              error: inspect(reason)
            })

          processing =
            not all_manifest_done?(socket.assigns.selected_canvases, manifest_results)

          assign(socket, manifest_results: manifest_results, manifest_processing: processing)

        nil ->
          dbg(reason)
          socket
      end

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

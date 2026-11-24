defmodule DpulCollections.Georef.Vlm do
  @moduledoc """
  Thin client for a local vision-language model served by `llama-server`
  (llama.cpp, OpenAI-compatible API). `ensure_server/0` launches it if nothing
  is listening yet.

  Set `GEOREF_HOST` to use a llama-server running elsewhere (e.g. a bigger
  Mac): it is never launched or killed from here, only checked for the
  expected model.

  Qwen3-VL reports points in a 0..1000 normalized frame of the image it was
  shown; `ask_json/3` returns the decoded JSON and callers map points back to
  canvas pixels.
  """
  require Logger

  @models %{
    qwen3vl_8b: {"Qwen3VL-8B-Instruct-Q8_0.gguf", "mmproj-Qwen3VL-8B-Instruct-F16.gguf"},
    qwen36_35b: {"Qwen3.6-35B-A3B-UD-Q4_K_M.gguf", "mmproj-Qwen3.6-35B-A3B-F16.gguf"}
  }

  def config do
    defaults = [
      model: String.to_atom(System.get_env("GEOREF_MODEL", "qwen3vl_8b")),
      model_dir: Path.expand("~/.cache/dpul_georef"),
      host: System.get_env("GEOREF_HOST"),
      port: String.to_integer(System.get_env("GEOREF_PORT", "8091")),
      ctx_size: 16_384
    ]

    Keyword.merge(defaults, Application.get_env(:dpul_collections, DpulCollections.Georef, []))
  end

  def base_url, do: "http://#{config()[:host] || "127.0.0.1"}:#{config()[:port]}"

  def ensure_server do
    cfg = config()
    {model, mmproj} = Map.fetch!(@models, cfg[:model])

    cond do
      healthy?() and loaded_model() == model ->
        :ok

      cfg[:host] ->
        raise "llama-server at #{base_url()} is not serving #{model} " <>
                "(loaded: #{inspect(loaded_model())}); start it there with that model"

      true ->
        start_local(cfg, model, mmproj)
    end
  end

  defp start_local(cfg, model, mmproj) do
    # Wrong model (or none) loaded: replace the server.
    System.cmd("pkill", ["-f", "llama-server.*--port #{cfg[:port]}"])
    Process.sleep(1000)
    dir = cfg[:model_dir]

    args = [
      "-m",
      Path.join(dir, model),
      "--mmproj",
      Path.join(dir, mmproj),
      "--port",
      to_string(cfg[:port]),
      "-c",
      to_string(cfg[:ctx_size]),
      "-ngl",
      "99",
      "-np",
      "1",
      "--jinja",
      "--image-max-tokens",
      "4096"
    ]

    Logger.info("starting llama-server #{model}")
    log = Path.join(dir, "llama-server.log")
    # Detached so the server outlives a single mix run and keeps its warm cache.
    System.cmd("sh", [
      "-c",
      "nohup llama-server #{Enum.map_join(args, " ", &shell_escape/1)} > #{log} 2>&1 &"
    ])

    wait_healthy(600)
  end

  defp shell_escape(s), do: "'" <> String.replace(s, "'", "'\\''") <> "'"

  defp loaded_model do
    case Req.get(base_url() <> "/v1/models", retry: false, receive_timeout: 2000) do
      {:ok, %{status: 200, body: %{"data" => [%{"id" => id} | _]}}} -> Path.basename(id)
      _ -> nil
    end
  end

  defp healthy? do
    match?(
      {:ok, %{status: 200}},
      Req.get(base_url() <> "/health", retry: false, receive_timeout: 2000)
    )
  end

  defp wait_healthy(0), do: raise("llama-server did not become healthy")

  defp wait_healthy(n) do
    if healthy?(),
      do: :ok,
      else:
        (
          Process.sleep(1000)
          wait_healthy(n - 1)
        )
  end

  @doc "Send one image (JPEG bytes) and a prompt; return {:ok, decoded_json} or {:error, raw}."
  def ask_json(image, prompt, opts \\ []) do
    # Grammar-constrain the answer to a JSON schema: some models (Qwen3.6)
    # otherwise narrate before answering and get cut off by max_tokens.
    text = ask(image, prompt, Keyword.put_new(opts, :schema, %{"type" => "object"}))

    case extract_json(text) do
      {:ok, json} -> {:ok, json}
      :error -> {:error, text}
    end
  end

  def ask(image, prompt, opts \\ []) do
    body = %{
      messages: [
        %{
          role: "user",
          content: [
            %{
              type: "image_url",
              image_url: %{url: "data:image/jpeg;base64," <> Base.encode64(image)}
            },
            %{type: "text", text: prompt}
          ]
        }
      ],
      temperature: 0,
      max_tokens: Keyword.get(opts, :max_tokens, 2048),
      cache_prompt: true,
      json_schema: Keyword.get(opts, :schema),
      # Hybrid-reasoning models (Qwen3.5/3.6) answer directly when told to.
      chat_template_kwargs: %{enable_thinking: false}
    }

    %{status: 200, body: resp} =
      Req.post!(base_url() <> "/v1/chat/completions",
        json: body,
        receive_timeout: 600_000,
        retry: false
      )

    get_in(resp, ["choices", Access.at(0), "message", "content"])
  end

  @doc "Schema for {\"point_2d\": [x, y] | null}."
  def point_schema do
    %{
      "type" => "object",
      "properties" => %{
        "point_2d" => %{
          "anyOf" => [
            %{
              "type" => "array",
              "items" => %{"type" => "number"},
              "minItems" => 2,
              "maxItems" => 2
            },
            %{"type" => "null"}
          ]
        }
      },
      "required" => ["point_2d"]
    }
  end

  @doc false
  def extract_json(text) do
    cleaned =
      text
      |> String.replace(~r/```(?:json)?/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, json} ->
        {:ok, json}

      _ ->
        case Regex.run(~r/[\[{].*[\]}]/s, cleaned) do
          [candidate] -> with({:ok, j} <- Jason.decode(candidate), do: {:ok, j}) |> ok_or_error()
          _ -> :error
        end
    end
  end

  defp ok_or_error({:ok, j}), do: {:ok, j}
  defp ok_or_error(_), do: :error
end

defmodule DpulCollections.Transcription do
  @timeout 900_000
  @flash "gemini-3-flash-preview"
  @pro "gemini-3-pro-preview"

  # Pricing per million tokens (in USD)
  @price_config %{
    @flash => %{input: 0.50, output: 3.00},
    @pro => %{input: 2.00, output: 12.00}
  }

  def model_options do
    [
      {"Gemini 3 Pro", @pro},
      {"Gemini 3 Flash", @flash}
    ]
  end

  def thinking_level_options do
    [
      {"Default (Usually High)", "none"},
      {"Minimal (Flash Only)", "minimal"},
      {"Low", "low"},
      {"Medium (Flash Only)", "medium"},
      {"High", "high"}
    ]
  end

  def default_model, do: @pro
  def default_thinking_level, do: "high"

  def transcribe_url(url, transcribe_model \\ @pro, bbox_model \\ @pro, opts \\ []) do
    transcribe_thinking = Keyword.get(opts, :transcribe_thinking, "medium")
    bbox_thinking = Keyword.get(opts, :bbox_thinking, "medium")

    {:ok, encoded_image} = fetch_and_encode(url)

    with {:ok, draft_json, usage1} <-
           step_1_transcribe_content(encoded_image, transcribe_model, transcribe_thinking),
         {:ok, grounded_json, usage2} <-
           step_2_generate_boxes(encoded_image, draft_json, bbox_model, bbox_thinking) do
      total_usage = %{
        input_tokens: usage1.input_tokens + usage2.input_tokens,
        output_tokens: usage1.output_tokens + usage2.output_tokens,
        total_tokens: usage1.total_tokens + usage2.total_tokens,
        step1: %{model: transcribe_model, thinking: transcribe_thinking, usage: usage1},
        step2: %{model: bbox_model, thinking: bbox_thinking, usage: usage2}
      }

      {:ok, grounded_json, total_usage}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_viewer_url(url, transcribe_model \\ @pro, bbox_model \\ @pro, opts \\ []) do
    gemini_url = "#{url}/full/!2048,2048/0/default.jpg"
    viewer_url = "#{url}/full/!1600,1600/0/default.jpg"

    {:ok, msg, usage} = transcribe_url(gemini_url, transcribe_model, bbox_model, opts)
    data_base64 = Jason.decode!(msg) |> Jason.encode!() |> Base.encode64()

    params = %{
      "img" => viewer_url,
      "base64" => data_base64
    }

    viewer_link = "https://tpendragon.github.io/ocr-viewer/index.html##{URI.encode_query(params)}"
    cost = calculate_cost(usage)

    {viewer_link, usage, cost}
  end

  defp step_1_transcribe_content(encoded_image, model, thinking_level) do
    prompt = """
    You are an expert digital archivist. Transcribe the **ENTIRE contents** of the provided image.

    # 1. SCOPE & LAYOUT
    - **Full Canvas Scan**: Analyze from edge to edge.
    - **Two-Page Spreads**: If two pages are visible, process both as separate regions but in the same array.
    - **Orientation**: Detect text orientation automatically.

    # 2. CRITICAL VISUAL DISTINCTION: COMPOUND EDITS
    Text often has multiple markings. Prioritize **TYPE** first, then **STYLE**.

    **Hierarchy of Types:**
    1. **Deletion**: Strikethrough or stamped out.
    2. **Insertion**: Written above/below with a caret.
    3. **Base**: Standard body text.

    **Visual Styles:**
    - "circled", "underlined", "boxed", "strikethrough"

    # 3. STRUCTURAL HIERARCHY
    - **Regions**: `paragraph`, `header`, `column`, `marginalia`, `page_number`, `shelf_mark`.
    - **Lines**: Group text into physical lines.
    - **Segments**: Split lines into atomic units (base text vs edits).

    **INSTRUCTION:**
    Focus strictly on capturing the text content and logical structure. Do NOT generate bounding boxes in this step.
    """

    schema = %{
      "type" => "ARRAY",
      "description" => "A list of semantic regions found on the page.",
      "items" => %{
        "type" => "OBJECT",
        "properties" => %{
          "region_type" => %{
            "type" => "STRING",
            "enum" => [
              "paragraph",
              "header",
              "column",
              "marginalia",
              "timestamp",
              "deleted_block",
              "shelf_mark",
              "bookplate",
              "seal",
              "page_number"
            ]
          },
          "lines" => %{
            "type" => "ARRAY",
            "items" => %{
              "type" => "OBJECT",
              "properties" => %{
                "line_number" => %{"type" => "INTEGER"},
                "segments" => %{
                  "type" => "ARRAY",
                  "items" => %{
                    "type" => "OBJECT",
                    "properties" => %{
                      "text" => %{"type" => "STRING"},
                      "type" => %{
                        "type" => "STRING",
                        "enum" => [
                          "base",
                          "insertion",
                          "deletion",
                          "substitution",
                          "handwritten_note"
                        ]
                      },
                      "style" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}}
                    },
                    "required" => ["text", "type"]
                  }
                }
              },
              "required" => ["segments"]
            }
          }
        },
        "required" => ["region_type", "lines"]
      }
    }

    call_gemini(encoded_image, prompt, schema, model, thinking_level)
  end

  defp step_2_generate_boxes(encoded_image, content_json, model, thinking_level) do
    json_string = Jason.encode!(Jason.decode!(content_json))

    prompt = """
    You are a Computer Vision Expert specializing in **Heavily Edited Manuscripts**.
    Your task is **Visual Grounding**.

    # INPUT CONTEXT
    #{json_string}

    # CRITICAL VISUAL RULES
    1. **Handwriting Physics**:
       - **Ascenders/Descenders**: Capture the full height of letters (l, h, g, y).
       - **Overlap**: Cursive lines often touch. It is OK for boxes to slightly overlap vertically.

    2. **COMPLEX EDITS & INSERTIONS (CRITICAL)**:
       - **Interlinear Insertions**: If a line has text inserted ABOVE it (e.g., with a caret ^), the Line Box MUST extend upward to include that inserted text.
       - **Result**: Edited lines will have **TALLER** boxes than regular lines. This is expected behavior.
       - **Marginalia**: If a line extends into the margin (e.g., a long insertion), extend the box horizontally to catch it.

    3. **"Zonal" Deletions**:
       - For blocks of text crossed out with a large scribble (like the "sine wave" at the top), the box should capture the ink of the text AND the strike-through line.

    # GEOMETRY CONSTRAINTS
    - **Scale**: 0-1000.
    - **Format**: [ymin, xmin, ymax, xmax].
    - **Tightness**: Ink-tight.

    # OUTPUT
    - Return the exact JSON structure with `box_2d` populated.
    """

    # Schema remains the same as previous step
    schema = %{
      "type" => "ARRAY",
      "items" => %{
        "type" => "OBJECT",
        "properties" => %{
          "region_type" => %{"type" => "STRING"},
          "box_2d" => %{
            "type" => "ARRAY",
            "description" => "Bounding box [ymin, xmin, ymax, xmax]",
            "items" => %{"type" => "INTEGER"}
          },
          "lines" => %{
            "type" => "ARRAY",
            "items" => %{
              "type" => "OBJECT",
              "properties" => %{
                "line_number" => %{"type" => "INTEGER"},
                "box_2d" => %{
                  "type" => "ARRAY",
                  "description" => "Bounding box [ymin, xmin, ymax, xmax]",
                  "items" => %{"type" => "INTEGER"}
                },
                "segments" => %{
                  "type" => "ARRAY",
                  "items" => %{
                    "type" => "OBJECT",
                    "properties" => %{
                      "text" => %{"type" => "STRING"},
                      "type" => %{"type" => "STRING"},
                      "style" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}}
                    },
                    "required" => ["text", "type"]
                  }
                }
              },
              "required" => ["box_2d", "segments"]
            }
          }
        },
        "required" => ["region_type", "box_2d", "lines"]
      }
    }

    call_gemini(encoded_image, prompt, schema, model, thinking_level)
  end

  defp call_gemini(data, prompt, schema, model, thinking_level) do
    json_body = %{
      "contents" => %{
        "role" => "user",
        "parts" => [
          %{
            "inlineData" => %{
              "mimeType" => "image/jpeg",
              "data" => data
            },
            "mediaResolution" => %{
              "level" => "media_resolution_high"
            }
          },
          %{"text" => prompt}
        ]
      },
      "generationConfig" =>
        %{
          "responseSchema" => schema,
          "responseMimeType" => "application/json"
        }
        |> maybe_add_thinking(thinking_level)
    }

    Req.post!(
      "https://aiplatform.googleapis.com/v1/projects/pul-gcdc/locations/global/publishers/google/models/#{model}:generateContent",
      auth: {:bearer, auth_token()},
      json: json_body,
      receive_timeout: @timeout
    )
    |> dbg
    |> Map.get(:body)
    |> handle_response()
  end

  defp handle_response(%{
         "candidates" => [%{"content" => %{"parts" => [%{"text" => response}]}}],
         "usageMetadata" => usage
       }) do
    token_usage = %{
      input_tokens: usage["promptTokenCount"] || 0,
      output_tokens: usage["candidatesTokenCount"] || 0,
      total_tokens: usage["totalTokenCount"] || 0
    }

    {:ok, response, token_usage}
  end

  defp handle_response(%{"candidates" => [%{"content" => %{"parts" => [%{"text" => response}]}}]}),
    do: {:ok, response, %{input_tokens: 0, output_tokens: 0, total_tokens: 0}}

  defp handle_response(%{"error" => err}), do: {:error, "Vertex API Error: #{err["message"]}"}
  defp handle_response(other), do: {:error, "Unexpected response format: #{inspect(other)}"}

  def fetch_and_encode(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Base.encode64(body)}

      {:ok, %{status: status}} ->
        {:error, "Image fetch failed with status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def auth_token() do
    %{token: token} = Goth.fetch!(DpulCollections.Goth)
    token
  end

  defp maybe_add_thinking(config, "none"), do: config

  defp maybe_add_thinking(config, thinking_level) when thinking_level in ["low", "medium", "high"] do
    Map.put(config, "thinkingConfig", %{"thinkingLevel" => thinking_level})
  end

  defp maybe_add_thinking(config, _), do: config

  def calculate_cost(usage) do
    step1_cost = calculate_step_cost(usage.step1.model, usage.step1.usage)
    step2_cost = calculate_step_cost(usage.step2.model, usage.step2.usage)

    total_cost = step1_cost + step2_cost

    %{
      step1: step1_cost,
      step2: step2_cost,
      total: total_cost
    }
  end

  defp calculate_step_cost(model, usage) do
    prices = @price_config[model]

    if prices do
      input_cost = usage.input_tokens / 1_000_000 * prices.input
      output_cost = usage.output_tokens / 1_000_000 * prices.output
      input_cost + output_cost
    else
      0.0
    end
  end
end

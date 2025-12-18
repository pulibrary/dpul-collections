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

    viewer_link =
      "https://tpendragon.github.io/ocr-viewer/section-viewer.html##{URI.encode_query(params)}"

    cost = calculate_cost(usage)

    {viewer_link, usage, cost}
  end

  defp step_1_transcribe_content(encoded_image, model, thinking_level) do
    prompt = """
    You are an expert Digital Archivist.
    Your goal is to transcribe the document while preserving its **Logical Layout**.
    These outputs may be used for section-level text embeddings, display to a user alongside its image, or for creating accessible PDFs.

    # 1. LAYOUT ANALYSIS
    - **Standard Blocks**: Paragraphs, headers, and marginalia.
    - **Visuals**: Images, stamps, seals (provide a description).
    - **NESTED COLUMNS (Crucial)**: If you encounter a section that is split into columns (e.g., **Signatures**, **Newspaper Columns**, **Lists of Names**), do NOT flatten them.
        - Create a parent region (e.g., `region_type: "signatures"`).
        - Create `sub_regions` for each distinct column or block within that parent.

    # 3. STRUCTURAL HIERARCHY
    - **General Rule**: Group related content into parent sections (e.g., `region_type: "section"`).
    - **Body Text**: If you find multiple paragraphs belonging to the same logical section, create a parent region.
        - **Sub-Regions**: The individual paragraphs MUST be `sub_regions` of that parent.
    - **Columns/Signatures**: Continue to use `sub_regions` for these as well.

    # 4. TRANSCRIPTION (Markdown)
    - Transcribe the content using Markdown.
    - If using `sub_regions`, the parent `markdown_content` can be null or a brief summary.
    - Transcribe the actual text inside the `sub_regions`.
    - **CONTINUOUS FLOW**: Do NOT preserve line breaks from the physical paper within a paragraph.
    - **DE-HYPHENATION**: If a word is hyphenated across two lines (e.g., "exam-" on line 1 and "ple" on line 2), join them into a single word ("example").
    - Use **Markdown** to denote structure within the block (e.g., **bold** for emphasis, # for headers).

    # 5. HANDLING TEXT EDITS & REVISIONS
    - **INSERTED TEXT** (interlinear, supralinear, marginal additions):
        - Include inserted text naturally in its intended position within the transcription
        - Do NOT use special notation like carets (^) or brackets
        - Simply incorporate it for maximum readability as if it were originally written there
    - **DELETED TEXT** (crossed out, struck through):
        - Mark deleted text using markdown strikethrough: ~~deleted text~~
        - Always preserve what was deleted so scholars can see the revision history
        - Example: "The ~~cat~~ dog ran" shows "cat" was deleted and replaced with "dog"

    **INSTRUCTION:**
    Analyze the layout. Use `sub_regions` strictly for multi-column or grouped layouts.
    """

    sub_region_schema = %{
      "type" => "OBJECT",
      "properties" => %{
        "region_type" => %{"type" => "STRING"},
        "classification" => %{"type" => "STRING", "nullable" => true},
        "label" => %{"type" => "STRING", "nullable" => true},
        "markdown_content" => %{"type" => "STRING"}
      },
      "required" => ["region_type", "markdown_content"]
    }

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
              "marginalia",
              "visual_content",
              "caption",
              "footer",
              "page_number",
              "shelf_mark",
              "section_break",
              "signatures",
              "columns",
              "section"
            ]
          },
          "classification" => %{"type" => "STRING", "nullable" => true},
          "label" => %{"type" => "STRING", "description" => "E.g. 'Witnesses', 'Principals'"},
          "markdown_content" => %{"type" => "STRING", "nullable" => true},
          "sub_regions" => %{
            "type" => "ARRAY",
            "description" => "Use ONLY for multi-column layouts like signatures.",
            "items" => sub_region_schema
          }
        },
        "required" => ["region_type"]
      }
    }

    call_gemini(encoded_image, prompt, schema, model, thinking_level)
  end

  defp step_2_generate_boxes(encoded_image, content_json, model, thinking_level) do
    json_string = Jason.encode!(Jason.decode!(content_json))

    prompt = """
    You are a Computer Vision Expert. Your task is **Hierarchical Visual Grounding**.

    # INPUT CONTEXT
    #{json_string}

    # INSTRUCTIONS
    For every region and **sub-region**, detect the bounding box.

    1. **Parent Regions**: If a region has `sub_regions`, the Parent Box must be large enough to encompass ALL its children (the union of the sub-boxes).
    2. **Sub-Regions**: Generate precise, ink-tight boxes for each individual column or signature block inside the parent.
    3. **Standard Regions**: Box the entire paragraph or visual element.

    # GEOMETRY
    - Scale: 0-1000.
    - Format: [ymin, xmin, ymax, xmax].

    # OUTPUT
    - Return the exact JSON structure with `box_2d` populated for EVERY item (parents and children).
    """

    sub_region_schema_with_box = %{
      "type" => "OBJECT",
      "properties" => %{
        "region_type" => %{"type" => "STRING"},
        "classification" => %{"type" => "STRING", "nullable" => true},
        "label" => %{"type" => "STRING", "nullable" => true},
        "markdown_content" => %{"type" => "STRING"},
        "box_2d" => %{"type" => "ARRAY", "items" => %{"type" => "INTEGER"}}
      },
      "required" => ["region_type", "markdown_content", "box_2d"]
    }

    schema = %{
      "type" => "ARRAY",
      "items" => %{
        "type" => "OBJECT",
        "properties" => %{
          "region_type" => %{"type" => "STRING"},
          "classification" => %{"type" => "STRING", "nullable" => true},
          "label" => %{"type" => "STRING", "nullable" => true},
          "markdown_content" => %{"type" => "STRING", "nullable" => true},
          "box_2d" => %{"type" => "ARRAY", "items" => %{"type" => "INTEGER"}},
          "sub_regions" => %{
            "type" => "ARRAY",
            "items" => sub_region_schema_with_box
          }
        },
        "required" => ["region_type", "box_2d"]
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

  defp maybe_add_thinking(config, thinking_level)
       when thinking_level in ["low", "medium", "high"] do
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

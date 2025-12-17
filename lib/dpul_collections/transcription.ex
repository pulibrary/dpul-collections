defmodule DpulCollections.Transcription do
  @timeout 900_000
  @model "gemini-3-flash-preview"

  def transcribe_url(url) do
    {:ok, encoded_image} = fetch_and_encode(url)

    with {:ok, draft_json} <- step_1_transcribe_content(encoded_image),
         {:ok, grounded_json} <- step_2_generate_boxes(encoded_image, draft_json) do
      {:ok, grounded_json}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_viewer_url(url) do
    gemini_url = "#{url}/full/!2048,2048/0/default.jpg"
    viewer_url = "#{url}/full/!1600,1600/0/default.jpg"

    {:ok, msg} = transcribe_url(gemini_url)
    data_base64 = Jason.decode!(msg) |> Jason.encode!() |> Base.encode64()

    params = %{
      "img" => viewer_url,
      "base64" => data_base64
    }

    "https://tpendragon.github.io/ocr-viewer/index.html##{URI.encode_query(params)}"
  end

  defp step_1_transcribe_content(encoded_image) do
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

    call_gemini(encoded_image, prompt, schema)
  end

  defp step_2_generate_boxes(encoded_image, content_json) do
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

    call_gemini(encoded_image, prompt, schema)
  end

  defp call_gemini(data, prompt, schema) do
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
      "generationConfig" => %{
        "responseSchema" => schema,
        "responseMimeType" => "application/json"
      }
    }

    Req.post!(
      "https://aiplatform.googleapis.com/v1/projects/pul-gcdc/locations/global/publishers/google/models/#{@model}:generateContent",
      auth: {:bearer, auth_token()},
      json: json_body,
      receive_timeout: @timeout
    )
    |> dbg
    |> Map.get(:body)
    |> handle_response()
  end

  defp handle_response(%{"candidates" => [%{"content" => %{"parts" => [%{"text" => response}]}}]}),
    do: {:ok, response}

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
end

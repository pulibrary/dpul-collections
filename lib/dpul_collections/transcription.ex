defmodule DpulCollections.Transcription do
  @timeout 900_000
  def transcribe_url(url) do
    {:ok, data} = fetch_and_encode(url)

    prompt_text = """
    You are an expert digital archivist. Transcribe the provided document, adapting your strategy to the material type (handwritten draft, printed newspaper, or clean letter).

    # CRITICAL VISUAL DISTINCTION: LINE PLACEMENT
        You must distinguish between **Deletions** and **Underlines**.
        1. **Strike-through (Deletion)**: The line passes **THROUGH** the center of the text characters.
           -> Mark as `type: "deletion"`.
        2. **Underline (Emphasis/Header)**: The line passes **BELOW** the text baseline.
           -> Mark as `type: "base"` or `type: "heading"` and set `style: "underlined"`.

    # STRUCTURAL HIERARCHY
    1. **Regions**: Group text into logical blocks (Paragraphs, Columns, Headers).
    2. **Lines**: Inside regions, identify the physical "Base Lines" of text.
    3. **Segments**: Inside lines, break text into atomic parts to handle edits.

    # HANDWRITING & EDITING RULES (For Manuscripts)
    - **Anchors**: Identify the main baseline of the sentence.
    - **Insertions**: If text is written *above* a line (with a caret `^` or loop), attach it to the line below it as an `insertion` segment.
    - **Deletions**: If text is crossed out or stamped over (like the "X" block), capture it but mark as `deletion`.
    - **Transpositions**: If a line connects a word to a new location, transcribe it in the *intended* final reading order if possible, or mark as `transposition`.

    # PRINT RULES (For Newspapers)
    - Respect columns strictly.
    - Do not merge text across the "gutter" between columns.
    """

    response_schema = %{
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
              "deleted_block"
            ],
            "description" => "The semantic function of this block."
          },
          "box_2d" => %{"type" => "ARRAY", "items" => %{"type" => "INTEGER"}},
          "lines" => %{
            "type" => "ARRAY",
            "items" => %{
              "type" => "OBJECT",
              "properties" => %{
                "line_number" => %{"type" => "INTEGER"},
                "box_2d" => %{
                  "type" => "ARRAY",
                  "description" => "Bounding box of the visual line strip.",
                  "items" => %{"type" => "INTEGER"}
                },
                "segments" => %{
                  "type" => "ARRAY",
                  "description" => "Atomic units of text within this line (base text vs edits).",
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
                        ],
                        "description" => "Type of text segment."
                      },
                      "style" => %{
                        "type" => "STRING",
                        "enum" => ["none", "underlined", "circled", "boxed"],
                        "description" =>
                          "Visual styling attributes. Use 'underlined' for lines below text."
                      },
                      "box_2d" => %{"type" => "ARRAY", "items" => %{"type" => "INTEGER"}}
                    },
                    "required" => ["text", "type", "box_2d"]
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

    json = %{
      "contents" => %{
        "role" => "user",
        "parts" => [
          %{
            "inlineData" => %{
              "mimeType" => "image/jpeg",
              "data" => data
            }
          },
          %{"text" => prompt_text}
        ]
      },
      "generationConfig" => %{
        "responseSchema" => response_schema,
        "temperature" => 0.3,
        "responseMimeType" => "application/json",
        "thinkingConfig" => %{
          "thinkingLevel" => "high"
        }
      }
    }

    Req.post!(
      "https://aiplatform.googleapis.com/v1/projects/pul-gcdc/locations/global/publishers/google/models/gemini-3-pro-preview:generateContent",
      auth: {:bearer, auth_token()},
      json: json,
      receive_timeout: @timeout
    ).body
    |> handle_response()
  end

  defp handle_response(%{"candidates" => [%{"content" => %{"parts" => [%{"text" => response}]}}]}),
    do: {:ok, response}

  defp handle_response(%{"error" => err}), do: {:error, "Vertex API Error: #{err["message"]}"}
  defp handle_response(other), do: {:error, "Unexpected response format: #{inspect(other)}"}

  def fetch_and_encode(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        base64_string = Base.encode64(body)
        {:ok, "#{base64_string}"}

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

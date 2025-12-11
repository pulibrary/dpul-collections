defmodule DpulCollections.Transcription do
  @timeout 900_000
  def transcribe_url(url) do
    {:ok, data} = fetch_and_encode(url)

    prompt_text = """
    You are an expert digital archivist. Transcribe the **ENTIRE contents** of the provided image, covering every visible page.

    # 1. SCOPE & LAYOUT (CRITICAL)
    - **Full Canvas Scan**: Analyze the image from the far-left edge to the far-right edge.
    - **Two-Page Spreads**: Check if the image contains two facing pages (a spread).
      - If TWO pages are visible, you **MUST** process both.
      - Treat the left page and right page as separate logical regions (e.g., separate `column` or `paragraph` blocks), but return them in the same array.
    - **Orientation**: Detect text orientation automatically. Do not ignore text based on language direction (LTR or RTL).
    - **COORDINATES MUST BE GLOBAL**. Do not reset (0,0) for every new paragraph region. (0,0) is always the top-left of the original image file.

    # 2. CRITICAL VISUAL DISTINCTION: COMPOUND EDITS
    Text often has multiple markings (e.g., crossed out AND circled). You must prioritize the **TYPE** first, then the **STYLE**.
    **Visual Styles (Array of Strings):**
    - Return a list of styles. If none apply, return empty list [].
    - **Correct:** style: ["circled", "deletion"]
    - **Incorrect:** style: "circled"

    **Hierarchy of Types (Select one):**
    1. **Deletion (Highest Priority)**: If text has a line THROUGH it (strike-through) OR is stamped out, `type` MUST be `"deletion"`.
       - *Even if it is also circled*, `type` remains `"deletion"`.
    2. **Insertion**: Text written above/below with a caret. `type` is `"insertion"`.
    3. **Base**: Standard body text.

    **Visual Styles (Apply Secondary Attributes):**
    - Check for visual wrappers *independent* of the type.
    - **Circle/Loop**: If the text (even deleted text) is surrounded by a loop -> set `style: "circled"`.
    - **Underline**: If a line is BELOW the text -> set `style: "underlined"`.
    - **Box**: If enclosed in a rectangle -> set `style: "boxed"`.

    **Examples:**
    - Text is crossed out: `type: "deletion"`, `style: "none"`
    - Text is circled: `type: "base"`, `style: "circled"`
    - Text is crossed out AND circled: `type: "deletion"`, `style: "circled"`

    # STRUCTURAL HIERARCHY & REGION DEFINITIONS
    1. **Regions**: Classify blocks into these specific types:
       - **Text Body**: `paragraph`, `header`, `column`.
       - **Manuscript Features**:
         - `marginalia`: Notes written in margins (often diagonal).
         - `page_number`: Foliation numbers usually in top corners.
       - **Library/Archival Metadata** (CRITICAL for Title Pages/Endpapers):
         - `shelf_mark`: Call numbers, usually alphanumeric (e.g., "ELS 834"), often boxed or on a sticker.
         - `bookplate`: Pasted "Ex Libris" papers or ownership labels.
         - `seal`: Official ink stamps (circular/oval) indicating library ownership.

    # 4. HANDWRITING & EDITING RULES (For Manuscripts)
    - **Anchors**: Identify the main baseline.
    - **Deletions**: If text is crossed out, `type` is ALWAYS `"deletion"`, regardless of other marks.
    - **Insertions**: If text is written *above* a line (with a caret `^` or loop), attach it to the line below it as an `insertion` segment.
    - **Deletions**: If text is crossed out or stamped over (like the "X" block), capture it but mark as `deletion`.
    - **Transpositions**: If a line connects a word to a new location, transcribe it in the *intended* final reading order if possible, or mark as `transposition`.

    # 5. PRINT RULES (For Newspapers)
    - Respect columns strictly.
    - Do not merge text across the "gutter" between columns or pages.

    # SPATIAL COORDINATE RULES (CRITICAL)
    1. **Scale**: All coordinates are integers 0-1000.
    2. **Order**: You MUST use `[ymin, xmin, ymax, xmax]` order.
    - The first number (`ymin`) is the vertical distance from the TOP edge.
    - The second number (`xmin`) is the horizontal distance from the LEFT edge.
    3. **Logic Check**:
    - `ymin` must be less than `ymax`.
    - `xmin` must be less than `xmax`.
    - If `ymin` > `ymax`, you have flipped the coordinates. FIX IT.

    # VISUAL ANCHORING & GEOMETRY RULES (STRICT)
    1. **"Ink-Tight" Boxes**: The `box_2d` must tightly enclose **EVERY PIXEL of ink** for that line.
       - **Top Edge**: Must touch the highest point of the tallest letter (ascender).
       - **Bottom Edge**: Must touch the lowest point of the lowest tail (descender).
       - **Drift Warning**: Do not let the box "float" in the whitespace above the text. If the box contains only whitespace, it is WRONG. Shift it down to hit the ink.
    2. **Overlap Prevention**:
       - Lines are stacked physically. The `ymax` of Line 1 should generally be less than or close to the `ymin` of Line 2.
       - If boxes heavily overlap vertically, you are failing to separate the lines.
    3. **Arabic Script Specifics**:
       - Pay special attention to "descenders" (letters dropping below the line). Ensure the bounding box extends DOWN far enough to catch them. Don't cut them off.

    # GEOMETRY & BOUNDING BOX RULES (STRICT)
    1. **NO INTERPOLATION**: Do NOT calculate box positions mathematically based on an average line height. Handwriting is irregular.
     - You must "trace" the ink of EACH line individually.
     - One line might be height 30, the next might be height 45. This is expected.
     - If your output shows perfectly equal spacing (e.g., +35, +35, +35), you are failing.
    2. **Tight Fit**: The box should hug the text. Do not include the whitespace between lines in the box.
    3. **Visual Confirmation**: Before finalizing a box, check: "Does this box actually contain the pixels of the text, or did I just guess where the line should be?"
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
              "deleted_block",
              "shelf_mark",
              "bookplate",
              "seal",
              "page_number"
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
                  "description" =>
                    "Bounding box in [ymin, xmin, ymax, xmax] order. 0-1000 scale.",
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
                        "type" => "ARRAY",
                        "items" => %{
                          "type" => "STRING",
                          "enum" => ["underlined", "circled", "boxed", "strikethrough"]
                        },
                        "description" => "List of all visual styles applied to this text."
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
            },
            "mediaResolution" => %{
              "level" => "media_resolution_high"
            }
          },
          %{"text" => prompt_text}
        ]
      },
      "generationConfig" => %{
        "responseSchema" => response_schema,
        "responseMimeType" => "application/json",
        "thinkingConfig" => %{
          "thinkingLevel" => "low"
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

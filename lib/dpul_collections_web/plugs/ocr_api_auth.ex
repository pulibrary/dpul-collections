defmodule DpulCollectionsWeb.Plugs.OcrApiAuth do
  # Quick and dirty auth as a proof of concept for requiring a bearer token.
  # TODO: If I extracted this there'd need to be some way to apply for these,
  # and have it identify who did the OCR. Maybe an opportunity to try ash
  # authentication?
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if valid_token?(conn) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, JSON.encode!(%{error: "unauthorized"}))
      |> halt()
    end
  end

  defp valid_token?(conn) do
    tokens = Application.get_env(:dpul_collections, :ocr_api_tokens, [])

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token in tokens
      _ -> false
    end
  end
end

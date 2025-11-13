defmodule DpulCollectionsWeb.HealthController do
  use DpulCollectionsWeb, :controller
  alias DpulCollections.Solr

  @doc """
  Checks application health and returns a JSON object relecting status
  """
  def show(conn, _params) do
    health = check_health([:index])

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      %{results: health} |> Jason.encode!()
    )
  end

  def check_health(options) when is_list(options) do
    options
    |> Enum.map(&check_health/1)
  end

  def check_health(:index) do
    %{name: "Solr", status: index_health()}
  end

  def index_health do
    with {:ok, response} <- Solr.Client.status(Solr.Index.read_index()),
         %Req.Response{status: 200} <- response do
      "OK"
    else
      _ -> "ERROR"
    end
  end
end

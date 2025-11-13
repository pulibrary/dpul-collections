defmodule DpulCollectionsWeb.HealthController do
  use DpulCollectionsWeb, :controller
  alias DpulCollections.Solr

  @doc """
  Checks application health and returns a JSON object relecting status
  """
  def show(conn, _params) do
    health = check_health([:index, :db])

    status = get_status(health)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      status,
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

  def check_health(:db) do
    %{name: "Database", status: db_health()}
  end

  def get_status(list = [hd | _]) when is_map(hd) do
    list
    |> Enum.map(fn x -> x[:status] end)
    |> Enum.dedup()
    |> get_status()
  end

  def get_status(["OK"]) do
    200
  end

  def get_status(_) do
    503
  end

  def index_health do
    with {:ok, response} <- Solr.Client.status(Solr.Index.read_index()),
         %Req.Response{status: 200} <- response do
      "OK"
    else
      _ -> "ERROR"
    end
  end

  def db_health do
    # TODO check via ecto
    "OK"
  end
end

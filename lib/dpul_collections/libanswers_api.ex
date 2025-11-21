defmodule DpulCollections.LibanswersApi do
  def create_ticket(params) do
    token = get_token()

    {:ok, response} =
      Req.post(
        create_ticket_url(),
        form: create_data(params),
        headers: %{"accept" => ["application/json"], "authorization" => "Bearer #{token}"}
      )

    case response.status do
      200 -> {:ok, response.body}
      _ -> {:error, response}
    end
  end

  # def enhance_message(message) do
  #   "#{@message}\n\nSent from #{current_url} via Libanswers API" if current_url
  #
  #   "#{@message}\n\nSent via Libanswers API"
  # end

  def create_data(%{message: message, name: name, email: email}) do
    %{
      quid: config()[:queue_id],
      pquestion: "Digital Collections Suggest a Correction Form",
      pdetails: message,
      pname: name,
      pemail: email
    }
  end

  def get_token do
    form_params = [
      client_id: config()[:client_id],
      client_secret: config()[:client_secret],
      grant_type: "client_credentials"
    ]

    {:ok, response} =
      Req.post(
        oauth_url(),
        form: form_params,
        headers: %{"accept" => ["application/json"]}
      )

    case response.status do
      200 -> response.body["access_token"]
      _ -> {:error, response}
    end
  end

  def extract_token({:ok, body}) do
    body
    |> Jason.decode!()
    |> Map.get("access_token")
  end

  def extract_ticket_url({:ok, body}) do
    body
    |> Jason.decode!()
    |> Map.get("ticketUrl")
  end

  def oauth_url do
    "https://faq.library.princeton.edu/api/1.1/oauth/token"
  end

  def create_ticket_url do
    "https://faq.library.princeton.edu/api/1.1/ticket/create"
  end

  def config do
    Application.fetch_env!(:dpul_collections, :libanswers)
  end
end

defmodule DpulCollections.LibanswersApi do
  def create_ticket(params) do
    with {:ok, token} <- get_token(),
         {:ok, response} <-
           Req.post(
             create_ticket_url(),
             form: create_data(params),
             headers: %{"accept" => ["application/json"], "authorization" => "Bearer #{token}"}
           ),
         %Req.Response{status: 200, body: body} <- response do
      {:ok, body}
    else
      {_, response} -> {:error, response}
      %Req.Response{status: status, body: body} -> {:error, %{status: status, body: body}}
    end
  end

  def create_data(params = %{"name" => name, "email" => email}) do
    %{
      quid: config()[:queue_id],
      pquestion: "Digital Collections Suggest a Correction Form",
      pdetails: enhance_message(params),
      pname: name,
      pemail: email
    }
  end

  def enhance_message(%{"message" => message, "item_id" => item_id}) do
    "#{message}\n\nSent from Digital Collections item #{item_id} via Libanswers API"
  end

  def get_token do
    form_params = [
      client_id: config()[:client_id],
      client_secret: config()[:client_secret],
      grant_type: "client_credentials"
    ]

    response_tuple =
      Req.post(
        oauth_url(),
        form: form_params,
        headers: %{"accept" => ["application/json"]}
      )

    with {:ok, response} <- response_tuple,
         200 <- response.status do
      {:ok, response.body["access_token"]}
    else
      {_, response} -> {:error, response.body}
    end
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

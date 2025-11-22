defmodule LibanswersApiFixtures do
  @moduledoc """
  A set of fixtures providing return values for Req.put to be used in test mocks
  """

  def oauth_response do
    {:ok,
     %Req.Response{
       status: 200,
       headers: %{
         "content-type" => ["application/json"]
       },
       body: %{
         "access_token" => "fake_token",
         "expires_in" => 86400,
         "scope" => "app_create",
         "token_type" => "Bearer"
       }
     }}
  end

  def oauth_error_response do
    {:error,
     %Req.Response{
       status: 400,
       headers: %{
         "content-type" => ["application/json"]
       },
       body: %{"error" => "The client credentials are invalid"}
     }}
  end

  def ticket_create_200 do
    {:ok,
     %Req.Response{
       status: 200,
       headers: %{
         "content-type" => ["application/json"]
       },
       body: %{
         "isShared" => false,
         "ticketUrl" => "http://mylibrary.libanswers.com/admin/ticket?qid=12345",
         "claimed" => 0
       }
     }}
  end

  def ticket_create_400 do
    {:ok,
     %Req.Response{
       status: 400,
       headers: %{
         "content-type" => ["application/json"]
       },
       body: %{"error" => "The grant type was not specified in the request"}
     }}
  end
end

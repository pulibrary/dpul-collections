defmodule DpulCollections.LibanswersApiTest do
  use DpulCollections.DataCase
  alias DpulCollections.LibanswersApi
  alias LibanswersApiFixtures
  import Mock

  describe "create_ticket/1" do
    test "is successful" do
      with_mock(Req,
        post: fn
          "https://faq.library.princeton.edu/api/1.1/oauth/token", _ ->
            LibanswersApiFixtures.oauth_response()

          "https://faq.library.princeton.edu/api/1.1/ticket/create",
          [
            form: %{
              quid: "my_queue",
              pquestion: "Digital Collections Suggest a Correction Form",
              pdetails: "a correction\n\nSent from Digital Collections item 2 via Libanswers API",
              pname: "me",
              pemail: "me@example.com"
            },
            headers: %{"accept" => ["application/json"], "authorization" => "Bearer fake_token"}
          ] ->
            LibanswersApiFixtures.ticket_create_200()
        end
      ) do
        {:ok, response_body} =
          LibanswersApi.create_ticket(%{
            "name" => "me",
            "email" => "me@example.com",
            "message" => "a correction",
            "item_id" => "2"
          })

        assert response_body["ticketUrl"] ==
                 "http://mylibrary.libanswers.com/admin/ticket?qid=12345"
      end
    end

    test "detects client error" do
      with_mock(Req,
        post: fn
          "https://faq.library.princeton.edu/api/1.1/oauth/token", _ ->
            LibanswersApiFixtures.oauth_response()

          "https://faq.library.princeton.edu/api/1.1/ticket/create", _ ->
            LibanswersApiFixtures.ticket_create_400()
        end
      ) do
        {:error, response} =
          LibanswersApi.create_ticket(%{
            "name" => "me",
            "email" => "me@example.com",
            "message" => "a correction",
            "item_id" => "2"
          })

        assert Map.keys(response.body) == ["error"]
      end
    end

    test "handles oauth error" do
      with_mock(Req,
        post: fn
          "https://faq.library.princeton.edu/api/1.1/oauth/token", _ ->
            LibanswersApiFixtures.oauth_error_response()
        end
      ) do
        {:error, response} =
          LibanswersApi.create_ticket(%{
            "name" => "me",
            "email" => "me@example.com",
            "message" => "a correction",
            "item_id" => "2"
          })

        assert Map.keys(response) == ["error"]
      end
    end
  end
end

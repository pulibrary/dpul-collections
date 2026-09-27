defmodule DpulCollections.Solr.ClientTest do
  use DpulCollections.DataCase
  use DpulCollections.TracingHelpers
  alias DpulCollections.Solr
  alias DpulCollections.Search.SearchState

  describe "query tracing" do
    test "records the POST params" do
      Tracer.with_span "parent" do
        %{"q" => "bananas", "filter" => %{"format" => "Posters"}}
        |> SearchState.from_params()
        |> Solr.query()
      end

      assert_receive {:span, span(name: "POST /solr/:collection/select", attributes: attributes)},
                     1000

      body = :otel_attributes.map(attributes)[:"http.request.body"]
      assert %{"filter" => [_ | _] = filters} = JSON.decode!(body)
      assert Enum.any?(filters, &(&1 =~ "Posters"))
    end
  end
end

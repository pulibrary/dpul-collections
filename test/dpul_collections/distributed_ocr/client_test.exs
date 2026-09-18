defmodule DpulCollections.DistributedOcr.ClientTest do
  use ExUnit.Case, async: false
  import Mock
  import ExUnit.CaptureLog
  alias DpulCollections.DistributedOcr.Client
  alias DpulCollections.Mocr

  setup do
    Application.put_env(:dpul_collections, Client,
      server_url: "http://ocr.test",
      token: "t",
      client_id: "c1"
    )

    on_exit(fn -> Application.delete_env(:dpul_collections, Client) end)
    :ok
  end

  defp claim_once(job, counter) do
    fn _req, opts ->
      cond do
        opts[:url] =~ "/result" ->
          {:ok, %Req.Response{status: 201, body: %{"id" => 1}}}

        Agent.get_and_update(counter, &{&1, &1 + 1}) == 0 ->
          {:ok, %Req.Response{status: 200, body: job}}

        true ->
          {:ok, %Req.Response{status: 204, body: ""}}
      end
    end
  end

  defp start_client! do
    start_supervised!({Client, name: :"client_#{System.unique_integer([:positive])}"})
  end

  test "claims a job, runs OCR, logs what it's working on, and posts the result" do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)

    test_pid = self()
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    job = %{
      "job_id" => 1,
      "image_url" => "https://example.com/1.jpg",
      "manifest_label" => "A Manifest",
      "mode" => "ocr"
    }

    log =
      capture_log([level: :info], fn ->
        with_mocks([
          {Req, [:passthrough],
           post: fn req, opts ->
             if opts[:url] =~ "/result", do: send(test_pid, {:result, opts[:json]})
             claim_once(job, counter).(req, opts)
           end},
          {Mocr, [:passthrough],
           ocr: fn _url, _mode -> "ocr text" end,
           model_info: fn -> %{model: "m", version: "1"} end}
        ]) do
          start_client!()

          assert_receive {:result, body}, 1000
          assert body[:text] == "ocr text"
          assert body[:model] == "m"
          assert body[:model_version] == "1"
          assert body[:client_id] == "c1"
        end
      end)

    assert log =~ "working on A Manifest"
    assert log =~ "finished A Manifest"
  end

  test "re-polls immediately when the server has no work (204)" do
    test_pid = self()

    with_mock Req, [:passthrough],
      post: fn _req, _opts ->
        send(test_pid, :polled)
        {:ok, %Req.Response{status: 204, body: ""}}
      end do
      start_client!()
      assert_receive :polled, 1000
    end
  end
end

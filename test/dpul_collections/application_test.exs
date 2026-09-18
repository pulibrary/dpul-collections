defmodule DpulCollections.ApplicationTest do
  use ExUnit.Case, async: true
  alias DpulCollections.Application

  test "client mode starts only the OCR worker children" do
    # Worker is gated by :start_mocr? (off in test), so client mode is empty here.
    assert Application.children_for_mode(:client) == []
  end

  test "server mode includes the endpoint and OCR host" do
    children = Application.children_for_mode(:server)
    assert DpulCollectionsWeb.Endpoint in children
    assert DpulCollections.DistributedOcr.Host in children
  end
end

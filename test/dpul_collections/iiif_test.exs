defmodule DpulCollections.IIIFTest do
  use ExUnit.Case, async: true
  alias DpulCollections.IIIF

  test "small_browse_thumbnail_parameters/0" do
    assert IIIF.small_browse_thumbnail_parameters() == "square/!100,100/0/default.jpg"
  end

  test "result_thumbnail_parameters/0" do
    assert IIIF.result_thumbnail_parameters() == "square/!350,350/0/default.jpg"
  end

  test "primary_search_thumbnail_parameters/0" do
    assert IIIF.primary_search_thumbnail_parameters() == "full/!350,350/0/default.jpg"
  end

  test "item_thumbnail_parameters/0" do
    assert IIIF.item_thumbnail_parameters() == "square/!350,465/0/default.jpg"
  end

  test "clover_thumbnail_parameters/0" do
    assert IIIF.clover_thumbnail_parameters() == "full/!200,150/0/default.jpg"
  end

  test "primary_thumbnail_parameters/2" do
    assert IIIF.primary_thumbnail_parameters(453, 800) == "full/!453,800/0/default.jpg"
  end
end

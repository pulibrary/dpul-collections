defmodule DpulCollections.Georef.ConsistencyTest do
  use ExUnit.Case, async: true

  alias DpulCollections.Georef.Consistency

  # 1 m per px, no rotation: a mask {u, v} lands on the ground at {u, -v}
  @identity %{a: 1.0, b: 0.0, tx: 0.0, ty: 0.0}

  defp sheet(label, x0, opts \\ []) do
    %{
      canvas: %{id: label},
      part: 1,
      label: label,
      status: :ok,
      scale: Keyword.get(opts, :scale, 1.0),
      transform: @identity,
      mask: [{x0, 0.0}, {x0 + 100.0, 0.0}, {x0 + 100.0, 100.0}, {x0, 100.0}]
    }
  end

  # A small-scale key map over the whole town, printing sheet numbers.
  defp key_map do
    %{
      sheet("Key map", -1000.0, scale: 10.0)
      | mask: [{-1000.0, -1000.0}, {1000.0, -1000.0}, {1000.0, 1000.0}, {-1000.0, 1000.0}]
    }
  end

  defp token(text, {x, y}, {w, h}, score \\ 0.95) do
    %{
      text: text,
      score: score,
      center: {x, y},
      quad: [
        {x - w / 2, y - h / 2},
        {x + w / 2, y - h / 2},
        {x + w / 2, y + h / 2},
        {x - w / 2, y + h / 2}
      ]
    }
  end

  # labels of the parts to decline
  defp declined(results, tokens_of \\ fn _ -> [] end) do
    Consistency.losers(results, tokens_of) |> Enum.map(fn {r, _} -> r.label end) |> Enum.uniq()
  end

  # Street names and index text are small; sheet numbers stand out by size.
  defp key_map_tokens(number_tokens) do
    fn
      %{id: "Key map"} ->
        [
          token("MAIN", {50.0, 10.0}, {80.0, 10.0}),
          token("ST", {60.0, 30.0}, {20.0, 10.0}),
          token("BROAD", {70.0, 80.0}, {60.0, 10.0}),
          # outside the key map's mask
          token("9", {5000.0, 5000.0}, {40.0, 40.0})
          | number_tokens
        ]

      _ ->
        []
    end
  end

  describe "key maps" do
    # Sheets 1 (x 0..100) and 2 (x 20..120) overlap by 80 %.
    test "a sheet number printed inside one sheet's footprint keeps that sheet" do
      in_sheet_2 = {110.0, 50.0}

      results = [sheet("Sheet 1", 0.0), sheet("Sheet 2", 20.0), key_map()]

      assert declined(results, key_map_tokens([token("2", in_sheet_2, {30.0, 30.0})])) == [
               "Sheet 1"
             ]

      assert declined(results, key_map_tokens([token("1", {10.0, 50.0}, {30.0, 30.0})])) == [
               "Sheet 2"
             ]
    end

    test "small, low-confidence or non-numeric tokens don't vouch for a sheet" do
      results = [sheet("Sheet 1", 0.0), sheet("Sheet 2", 20.0), key_map()]

      tokens = [
        token("2", {110.0, 50.0}, {12.0, 12.0}),
        token("2", {112.0, 50.0}, {30.0, 30.0}, 0.5),
        token("2a", {114.0, 50.0}, {30.0, 30.0})
      ]

      assert declined(results, key_map_tokens(tokens)) == ["Sheet 1", "Sheet 2"]
    end

    test "a part whose label names no sheet can't be vouched for" do
      results = [sheet("Insert", 0.0), sheet("Sheet 2", 20.0), key_map()]

      assert declined(results, key_map_tokens([token("2", {110.0, 50.0}, {30.0, 30.0})])) == [
               "Insert"
             ]
    end
  end

  test "both same-scale parts overlapping by more than half are declined" do
    results = [sheet("Sheet 1", 0.0), sheet("Sheet 2", 20.0), sheet("Sheet 3", 300.0)]
    assert declined(results) == ["Sheet 1", "Sheet 2"]
  end

  test "overlaps between different scales don't count" do
    assert declined([sheet("Sheet 1", 0.0), sheet("Sheet 2", 20.0, scale: 2.0)]) == []
  end

  test "overlap/2 is the shared fraction of the smaller polygon" do
    a = [{0.0, 0.0}, {100.0, 0.0}, {100.0, 100.0}, {0.0, 100.0}]
    b = [{50.0, 0.0}, {150.0, 0.0}, {150.0, 100.0}, {50.0, 100.0}]
    assert_in_delta Consistency.overlap(a, b), 0.5, 0.03
    assert Consistency.overlap(a, Enum.map(a, fn {x, y} -> {x + 200, y} end)) == 0.0
  end

  test "failed parts and an empty atlas have no conflicts" do
    assert Consistency.losers([], fn _ -> [] end) == []
    failed = %{sheet("Sheet 1", 0.0) | status: :failed}
    assert Consistency.losers([failed, sheet("Sheet 2", 20.0)], fn _ -> [] end) == []
  end

  test "conflicts/1 pairs same-scale footprints overlapping by more than half" do
    a = sheet("Sheet 1", 0.0)
    b = sheet("Sheet 2", 40.0)
    c = sheet("Sheet 3", 60.0)
    assert Consistency.conflicts([a, b, c]) == [{a, b}, {b, c}]
  end

  test "footprint/1 maps the mask through the transform" do
    assert Consistency.footprint(sheet("Sheet 1", 0.0)) ==
             [{0.0, 0.0}, {100.0, 0.0}, {100.0, -100.0}, {0.0, -100.0}]
  end
end

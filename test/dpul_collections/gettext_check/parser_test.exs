defmodule DpulCollections.GettextCheck.ParserTest do
  alias DpulCollections.GettextCheck.Parser
  use DpulCollections.DataCase, async: true

  describe ".missing_gettext" do
    test "returns files and lines that are missing gettext calls in the root" do
      results = Parser.missing_gettext("spec/fixtures/gettext_files/missing_gettext.ex")
      assert length(results) == 4
      assert hd(results) == %{text: "Hi everyone, this is missing a gettext!", line: 4}
      assert Enum.at(results, 1) == %{text: "This is missing gettext, but in a tag!", line: 7}
      assert Enum.at(results, 2) == %{text: "\"Not translated!\"", line: 14}
    end
  end
end

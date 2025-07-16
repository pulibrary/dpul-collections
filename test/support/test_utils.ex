alias PhoenixTest.Playwright.Frame

defmodule TestUtils do
  def clean_string(string) do
    # Replaces non-breaking space with regular space
    # Collapses all whitespace into a single space
    # Trims leading/trailing spaces
    string
    |> String.replace("\u00A0", " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def assert_a11y(opts, filter) do
    run_a11y(opts)
    |> A11yAudit.Assertions.assert_no_violations(filter: filter)
  end

  def assert_a11y(opts) do
    run_a11y(opts)
    |> A11yAudit.Assertions.assert_no_violations()
  end

  defp run_a11y(%{frame_id: frame_id}) do
    Frame.evaluate(frame_id, A11yAudit.JS.axe_core())

    frame_id
    |> Frame.evaluate("axe.run()")
    |> A11yAudit.Results.from_json()
  end
end

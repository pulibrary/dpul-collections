alias PlaywrightEx.Frame

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

  def assert_a11y(args, filter) do
    run_a11y(args)
    |> A11yAudit.Assertions.assert_no_violations(filter: filter)
  end

  def assert_a11y(args) do
    run_a11y(args)
    |> A11yAudit.Assertions.assert_no_violations()
  end

  defp run_a11y(%{frame_id: frame_id}) do
    Frame.evaluate(frame_id, expression: A11yAudit.JS.axe_core(), timeout: 5000)

    {:ok, json} = Frame.evaluate(frame_id, expression: "axe.run()", timeout: 5000)

    json
    |> A11yAudit.Results.from_json()
  end
end

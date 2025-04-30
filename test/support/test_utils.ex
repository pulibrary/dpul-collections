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
end

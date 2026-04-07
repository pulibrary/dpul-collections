defmodule DpulCollections.IndexingPipeline.Figgy.ImportedCatalogSchema do
  alias DpulCollections.IndexingPipeline.Figgy
  use DpulCollections.IndexingPipeline.Figgy.ImportedCatalogSchema.Constants
  defmacro descriptive_attributes, do: @descriptive_attributes
  defmacro marc_relators, do: @marc_relators
  defmacro iiif_fields, do: @iiif_fields
  defstruct @marc_relators ++ @iiif_fields ++ @descriptive_attributes

  def from_resource(%Figgy.Resource{metadata: %{"imported_metadata" => [metadata]}}) do
    struct(
      Figgy.ImportedCatalogSchema,
      safe_atomize_keys(metadata)
    )
  end

  defp safe_atomize_keys(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      new_key =
        try do
          String.to_existing_atom(key)
        rescue
          # Keeps string if atom doesn't exist
          ArgumentError -> key
        end

      Map.put(acc, new_key, value)
    end)
  end
end

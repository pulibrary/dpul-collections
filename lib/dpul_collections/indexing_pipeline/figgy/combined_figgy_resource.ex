defmodule DpulCollections.IndexingPipeline.Figgy.CombinedFiggyResource do
  @moduledoc """
  Struct that enriches a Figgy resource with related data, related ids, and cache marker.
  """

  @enforce_keys [
    :resource,
    :related_data,
    :related_ids
  ]
  defstruct [:persisted_member_ids, :latest_updated_marker | @enforce_keys]
end

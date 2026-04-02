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

  @type related_data() :: %{optional(field_name :: String.t()) => related_resource_map()}
  @type related_resource_map() :: %{
          optional(resource_id :: String.t()) => resource_struct :: map()
        }
end

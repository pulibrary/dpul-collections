defmodule DpulCollections.Collection do
  use Gettext, backend: DpulCollectionsWeb.Gettext

  defstruct [
    :id,
    :slug,
    :title,
    :tagline,
    :description,
    :item_count,
    categories: [],
    genres: [],
    languages: [],
    geographic_origins: []
  ]
end

defmodule DpulCollections do
  @moduledoc """
  DpulCollections keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  def is_production() do
    Application.get_env(:dpul_collections, :environment_name) == "production"
  end
end

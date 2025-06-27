defmodule EmbedAnything do
  use Rustler, otp_app: :dpul_collections, crate: "embedanything"

  # When your NIF is loaded, it will override this function.
  def embed_text(_text), do: :erlang.nif_error(:nif_not_loaded)
end

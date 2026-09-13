defmodule DpulCollections.Ocr.Native do
  # Bindings to Rust code.
  use Rustler,
    otp_app: :dpul_collections,
    crate: :dpul_ocr,
    features: if(:os.type() == {:unix, :darwin}, do: ["metal"], else: [])

  def load_model(_model_dir, _device), do: :erlang.nif_error(:nif_not_loaded)

  def load_layout(_model_dir, _device), do: :erlang.nif_error(:nif_not_loaded)

  def load_paddle(_model_dir, _device), do: :erlang.nif_error(:nif_not_loaded)

  def ocr_path(_resource, _image_path, _max_new_tokens), do: :erlang.nif_error(:nif_not_loaded)

  def layout_ocr_path(_ocr, _layout, _image_path), do: :erlang.nif_error(:nif_not_loaded)

  def layout_paddle_ocr_path(_paddle, _layout, _image_path),
    do: :erlang.nif_error(:nif_not_loaded)
end

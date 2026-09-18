defmodule DpulCollections.Mocr.Native do
  use Rustler,
    otp_app: :dpul_collections,
    crate: "dpul_mocr",
    env: [
      {"CFLAGS", "-Wno-elaborated-enum-base"},
      {"CXXFLAGS", "-Wno-elaborated-enum-base"}
    ]

  def load(_model_path, _mmproj_path), do: :erlang.nif_error(:nif_not_loaded)
  def ocr(_model, _image, _prompt, _n_ctx), do: :erlang.nif_error(:nif_not_loaded)
end

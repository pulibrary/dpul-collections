url =
  "https://iiif-cloud.princeton.edu/iiif/2/92%2Fc0%2F75%2F92c075093b8b42129f12ca7e260182ae%2Fintermediate_file/full/1000,1700/0/default.jpg"

IO.puts("== starting OCR (download + load may take a while) ==")
t0 = System.monotonic_time(:millisecond)
text = DpulCollections.Mocr.ocr(url, :ocr)
dt = System.monotonic_time(:millisecond) - t0
IO.puts("== OCR done in #{dt} ms ==")
IO.puts("== TRANSCRIPTION ==")
IO.puts(text)
IO.puts("== END ==")

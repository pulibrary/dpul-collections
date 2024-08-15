defmodule FiggyTestSupport do
  def markers do
    marker1 = {~U[2018-03-09 20:19:33.414040Z], "3cb7627b-defc-401b-9959-42ebc4488f74"}
    marker2 = {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"}
    marker3 = {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"}
    {marker1, marker2, marker3}
  end
end

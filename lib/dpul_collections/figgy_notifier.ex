defmodule DpulCollections.FiggyNotifier do
  alias DpulCollections.FiggyRepo

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Postgrex.Notifications, :start_link, [[{:name, __MODULE__} | FiggyRepo.config()]]}
    }
  end
end

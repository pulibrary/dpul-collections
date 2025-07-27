defmodule DpulCollections.Greeter do
  @moduledoc "Greet someone warmly"

  use Hermes.Server.Component, type: :tool
  alias Hermes.Server.Response

  schema do
    field :name, :string, required: true
  end

  @impl true
  def execute(%{name: name}, frame) do
    {:reply, Response.text(Response.tool(), "Hello #{name}! Welcome to the MCP world!"), frame}
  end
end

# Define a server with tools capabilities
defmodule DpulCollections.MCPServer do
  use Hermes.Server,
    name: "My Server",
    version: "1.0.0",
    capabilities: [:tools]

  component(DpulCollections.Greeter)
end

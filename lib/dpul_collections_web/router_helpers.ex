defmodule DpulCollectionsWeb.RouterHelpers do
  @moduledoc """
  Compile-time helpers for the Router.
  """
  @sql_sandbox_enabled Application.compile_env(:dpul_collections, :sql_sandbox, false)

  # Add a macro to conditionally add sandbox support to a list of LiveView
  # on_mount hooks. Similar to code here: https://hexdocs.pm/phoenix_ecto/Phoenix.Ecto.SQL.Sandbox.html#module-acceptance-tests-with-liveviews
  # This is a macro so that it happens at compile time.
  defmacro with_sandbox_support(hooks) do
    if @sql_sandbox_enabled do
      quote do
        [LiveAcceptance | unquote(hooks)]
      end
    else
      hooks
    end
  end
end

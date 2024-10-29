defmodule DpulCollectionsWeb.Router do
  use DpulCollectionsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DpulCollectionsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :dashboard_auth do
    plug :basic_auth
  end

  defp basic_auth(conn, _opts) do
    username = Application.fetch_env!(:dpul_collections, :basic_auth_username)
    password = Application.fetch_env!(:dpul_collections, :basic_auth_password)
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end

  scope "/", DpulCollectionsWeb do
    pipe_through :browser

    live "/", HomeLive, :live
    live "/search", SearchLive, :live
    live "/item/:id", ItemLive, :live
    live "/i/item/:id", ItemLive, :live
    live "/i/:slug/item/:id", ItemLive, :live
  end

  # Other scopes may use custom stacks.
  # scope "/api", DpulCollectionsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dpul_collections, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:dashboard_auth, :browser]

      live_dashboard "/dashboard",
        metrics: DpulCollectionsWeb.Telemetry,
        additional_pages: [
          broadway: BroadwayDashboard
        ]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

defmodule DpulCollectionsWeb.UserLive.Login do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext

  alias DpulCollections.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app current_path={@current_path} flash={@flash} current_scope={@current_scope}>
      <.login_page :if={!@verify_email} {assigns} />
      <.verify_page :if={@verify_email} {assigns} />
    </Layouts.app>
    """
  end

  def login_page(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4">
      <div class="text-center">
        <.header>
          <p>{gettext("Log in")}</p>
          <:subtitle>
            <%= if @current_scope do %>
              {gettext("You need to reauthenticate to perform sensitive actions on your account.")}
            <% end %>
          </:subtitle>
        </.header>
      </div>

      <.form
        :let={f}
        for={@form}
        id="login_form_magic"
        action={~p"/users/log-in"}
        phx-submit="submit_magic"
        class="flex flex-col gap-6"
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
          phx-mounted={JS.focus()}
        />
        <.primary_button class="btn btn-primary w-full">
          {gettext("Log in with email")}
        </.primary_button>
      </.form>
    </div>
    """
  end

  def verify_page(assigns) do
    ~H"""
    <div class="content-area text-lg flex flex-col gap-6">
      <div class="text-center flex flex-col gap-2">
        <.header>
          <p>{gettext("We emailed you a code")}</p>
        </.header>
        <% # this is only for dev, so not covered in test %>
        <% # coveralls-ignore-start %>
        <div
          :if={local_mail_adapter?()}
          class="flex gap-2 justify-center items-center alert alert-info"
        >
          <.icon name="hero-information-circle" class="size-6 shrink-0 grow-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>
        <% # coveralls-ignore-end %>

        <p>
          {gettext("We sent an email to %{email}.", %{email: @verify_email})}<br />{gettext(
            "Click the link in that email to log in."
          )}
        </p>
        <p>{gettext("If you don't see the email, check your spam or junk folder.")}</p>
      </div>
      <div class="text-center">
        {gettext("Can't find your link?")}
        <.link class="text-accent" phx-click="resend_link">{gettext("Resend link")}</.link>
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     assign(socket,
       verify_email: nil,
       form: form,
       trigger_submit: false,
       return_to: params["return_to"]
     )}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    # Include return_to in the magic link URL if it exists
    magic_link_url_fun = &url(~p"/users/log-in/#{&1}?#{%{return_to: socket.assigns.return_to}}")

    Accounts.deliver_login_instructions(email, magic_link_url_fun)

    {:noreply,
     socket
     |> assign(:verify_email, email)}
  end

  def handle_event("resend_link", _params, socket = %{assigns: %{verify_email: verify_email}}) do
    socket =
      put_flash(socket, :info, gettext("An email has been re-sent, please check your inbox."))

    handle_event("submit_magic", %{"user" => %{"email" => verify_email}}, socket)
  end

  defp local_mail_adapter? do
    Application.get_env(:dpul_collections, DpulCollections.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end
end

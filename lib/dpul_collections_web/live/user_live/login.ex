defmodule DpulCollectionsWeb.UserLive.Login do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext

  alias DpulCollections.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
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

        <% # this is only for dev, so not covered in test %>
        <% # coveralls-ignore-start %>
        <div :if={local_mail_adapter?()} class="flex gap-2 items-center alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0 grow-0" />
          <div class="grow">
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>
        <% # coveralls-ignore-end %>

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
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    Accounts.deliver_login_instructions(
      email,
      &url(~p"/users/log-in/#{&1}")
    )

    info =
      gettext("You will receive instructions for logging in shortly.")

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:dpul_collections, DpulCollections.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end
end

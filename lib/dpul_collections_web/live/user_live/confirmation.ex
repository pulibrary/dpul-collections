defmodule DpulCollectionsWeb.UserLive.Confirmation do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext

  alias DpulCollections.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="content-area flex flex-col items-center justify-center gap-6">
        <div class="text-center">
          <.header>
            {gettext("Welcome")}
            <:subtitle>{gettext("Logging in %{email}", %{email: @user.email})}</:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
          class="flex gap-4"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <input
            type="hidden"
            name={@form[:return_to].name}
            value={@form[:return_to].value}
          />
          <div class="flex flex-wrap gap-4 justify-center">
            <.primary_button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Logging in..."
            >
              {gettext("Keep me logged in on this device")}
            </.primary_button>
            <.primary_button phx-disable-with="Logging in...">
              {gettext("Log me in only this time")}
            </.primary_button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token} = params, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token, "return_to" => params["return_to"]}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Magic link is invalid or it has expired."))
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end

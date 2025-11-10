defmodule DpulCollections.Accounts.UserNotifier do
  import Swoosh.Email

  alias DpulCollections.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Princeton Digital Collections", "noreply@princeton.edu"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Digital Collections update email link", """
    Hi #{user.email},

    You can change the email address you use for the Princeton University Library Digital Collections site by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    deliver(user.email, "Digital Collections log-in link", """
    Hi #{user.email},

    You can log into your Princeton University Library Digital Collections account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    """)
  end
end

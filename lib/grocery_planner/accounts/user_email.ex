defmodule GroceryPlanner.Accounts.UserEmail do
  @moduledoc """
  Email functions for user account operations.
  """

  import Swoosh.Email

  alias GroceryPlanner.Mailer

  @from_email "noreply@groceryplanner.com"
  @from_name "Grocery Planner"

  @doc """
  Sends a password reset email to the user with a link to reset their password.
  """
  def send_password_reset_email(user, reset_url) do
    email =
      new()
      |> to({user.name, to_string(user.email)})
      |> from({@from_name, @from_email})
      |> subject("Reset your password")
      |> html_body(password_reset_html(user, reset_url))
      |> text_body(password_reset_text(user, reset_url))

    Mailer.deliver(email)
  end

  defp password_reset_html(user, reset_url) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .button { display: inline-block; padding: 12px 24px; background-color: #2563eb; color: white; text-decoration: none; border-radius: 6px; font-weight: 600; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 14px; color: #666; }
      </style>
    </head>
    <body>
      <div class="container">
        <h2>Reset Your Password</h2>
        <p>Hi #{user.name},</p>
        <p>We received a request to reset your password for your Grocery Planner account. Click the button below to set a new password:</p>
        <p style="margin: 30px 0;">
          <a href="#{reset_url}" class="button">Reset Password</a>
        </p>
        <p>Or copy and paste this link into your browser:</p>
        <p style="word-break: break-all; color: #2563eb;">#{reset_url}</p>
        <p>This link will expire in 1 hour for security reasons.</p>
        <p>If you didn't request this password reset, you can safely ignore this email. Your password will remain unchanged.</p>
        <div class="footer">
          <p>Thanks,<br>The Grocery Planner Team</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp password_reset_text(user, reset_url) do
    """
    Reset Your Password

    Hi #{user.name},

    We received a request to reset your password for your Grocery Planner account.

    Click the link below to set a new password:
    #{reset_url}

    This link will expire in 1 hour for security reasons.

    If you didn't request this password reset, you can safely ignore this email. Your password will remain unchanged.

    Thanks,
    The Grocery Planner Team
    """
  end
end

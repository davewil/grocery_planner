defmodule GroceryPlanner.Notifications.EmailScheduler do
  @moduledoc false
  use GenServer

  alias GroceryPlanner.Mailer
  alias GroceryPlanner.Notifications.ExpirationAlerts
  alias GroceryPlanner.Notifications.NotificationPreference
  alias GroceryPlanner.Notifications.RecipeSuggestions
  alias Swoosh.Email

  require Ash.Query
  require Logger

  # 7 AM UTC
  @email_time_hour 7
  # 0 minutes
  @email_time_minute 0

  # Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  # Server (callbacks)

  @impl true
  def init(:ok) do
    schedule_email_send()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:send_daily_emails, state) do
    send_daily_emails()
    schedule_email_send()
    {:noreply, state}
  end

  defp send_daily_emails do
    Logger.info("Sending daily notification emails...")

    NotificationPreference
    |> Ash.Query.filter(email_notifications_enabled == true)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn preference ->
      # Use Ash.load! directly on the resource
      user = Ash.load!(preference.user, [:account], authorize?: false)
      account = Ash.load!(preference.account, [:users], authorize?: false)

      if user && account do
        send_notification_email_for_user(preference, user, account)
      else
        Logger.warning(
          "Skipping email for preference #{preference.id}: User or Account not found."
        )
      end
    end)
  end

  defp send_notification_email_for_user(preference, user, account) do
    # Get expiration alerts summary
    {:ok, expiration_summary} =
      ExpirationAlerts.get_expiring_summary(account.id, user,
        days_threshold: preference.expiration_alert_days
      )

    # Get recipe suggestions
    {:ok, recipe_suggestions} =
      RecipeSuggestions.get_suggestions_for_expiring_items(account.id, user)

    email_content =
      render_email_content(
        user,
        account,
        expiration_summary,
        recipe_suggestions,
        preference.expiration_alert_days
      )

    case email_content do
      {:ok, html_body} ->
        email =
          %Email{}
          |> Email.to({user.name, user.email})
          |> Email.from({"Grocery Planner", "notifications@groceryplanner.com"})
          |> Email.subject("Your Daily Grocery Planner Digest for #{Date.utc_today()}")
          |> Email.html_body(html_body)

        case Mailer.deliver(email) do
          {:ok, _metadata} ->
            Logger.info("Sent daily digest email to #{user.email}")

          {:error, reason} ->
            Logger.error("Failed to send daily digest email to #{user.email}: #{inspect(reason)}")
        end
    end
  end

  defp render_email_content(user, account, expiration_summary, recipe_suggestions, days_threshold) do
    expiration_rows = build_expiration_rows(expiration_summary, days_threshold)
    recipe_rows = build_recipe_rows(recipe_suggestions)
    today = Date.utc_today() |> Calendar.strftime("%B %d, %Y")

    body = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Grocery Planner Daily Digest</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f4f4f5;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f4f4f5;">
        <tr>
          <td align="center" style="padding: 40px 20px;">
            <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
              <!-- Header -->
              <tr>
                <td style="padding: 32px 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px 12px 0 0;">
                  <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">Grocery Planner</h1>
                  <p style="margin: 8px 0 0; color: rgba(255,255,255,0.9); font-size: 14px;">Daily Digest for #{today}</p>
                </td>
              </tr>

              <!-- Greeting -->
              <tr>
                <td style="padding: 32px 40px 24px;">
                  <p style="margin: 0; color: #374151; font-size: 16px; line-height: 1.6;">
                    Hello <strong>#{escape_html(user.name)}</strong>,
                  </p>
                  <p style="margin: 12px 0 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                    Here's what's happening in your household <strong>#{escape_html(account.name)}</strong> today.
                  </p>
                </td>
              </tr>

              <!-- Expiration Alerts Section -->
              <tr>
                <td style="padding: 0 40px 24px;">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #fef3c7; border-radius: 8px; border-left: 4px solid #f59e0b;">
                    <tr>
                      <td style="padding: 20px;">
                        <h2 style="margin: 0 0 16px; color: #92400e; font-size: 18px; font-weight: 600;">
                          ⚠️ Expiration Alerts
                        </h2>
                        <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                          #{expiration_rows}
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Recipe Suggestions Section -->
              #{if Enum.any?(recipe_suggestions) do
      """
      <tr>
        <td style="padding: 0 40px 24px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #ecfdf5; border-radius: 8px; border-left: 4px solid #10b981;">
            <tr>
              <td style="padding: 20px;">
                <h2 style="margin: 0 0 16px; color: #065f46; font-size: 18px; font-weight: 600;">
                  🍳 Recipe Suggestions
                </h2>
                <p style="margin: 0 0 12px; color: #047857; font-size: 14px;">
                  Use up expiring ingredients with these recipes:
                </p>
                #{recipe_rows}
              </td>
            </tr>
          </table>
        </td>
      </tr>
      """
    else
      ""
    end}

              <!-- CTA Button -->
              <tr>
                <td align="center" style="padding: 8px 40px 32px;">
                  <a href="#" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; font-weight: 600; font-size: 15px; border-radius: 8px;">
                    View Full Details
                  </a>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="padding: 24px 40px; background-color: #f9fafb; border-radius: 0 0 12px 12px; border-top: 1px solid #e5e7eb;">
                  <p style="margin: 0; color: #9ca3af; font-size: 13px; text-align: center;">
                    You're receiving this email because you enabled daily digest notifications.
                  </p>
                  <p style="margin: 8px 0 0; color: #9ca3af; font-size: 13px; text-align: center;">
                    © #{Date.utc_today().year} Grocery Planner
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """

    {:ok, body}
  end

  defp build_expiration_rows(summary, days_threshold) do
    rows = [
      {:expired, summary.expired_count, "#dc2626", "Expired"},
      {:today, summary.today_count, "#ea580c", "Expiring Today"},
      {:tomorrow, summary.tomorrow_count, "#d97706", "Expiring Tomorrow"},
      {:this_week, summary.this_week_count, "#ca8a04", "This Week"},
      {:soon, summary.soon_count, "#65a30d", "Within #{days_threshold} Days"}
    ]

    rows
    |> Enum.filter(fn {_key, count, _color, _label} -> count > 0 end)
    |> Enum.map(fn {_key, count, color, label} ->
      """
      <tr>
        <td style="padding: 6px 0;">
          <span style="display: inline-block; width: 12px; height: 12px; background-color: #{color}; border-radius: 50%; margin-right: 8px; vertical-align: middle;"></span>
          <span style="color: #78350f; font-size: 14px;">#{label}:</span>
          <strong style="color: #78350f; font-size: 14px; margin-left: 4px;">#{count}</strong>
        </td>
      </tr>
      """
    end)
    |> Enum.join("\n")
    |> case do
      "" ->
        "<tr><td style='color: #047857; font-size: 14px;'>No items expiring soon. Great job!</td></tr>"

      rows ->
        rows
    end
  end

  defp build_recipe_rows(suggestions) do
    suggestions
    |> Enum.take(5)
    |> Enum.map(fn suggestion ->
      """
      <div style="background-color: #ffffff; border-radius: 6px; padding: 12px; margin-bottom: 8px;">
        <strong style="color: #065f46; font-size: 14px;">#{escape_html(suggestion.recipe.name)}</strong>
        <p style="margin: 4px 0 0; color: #047857; font-size: 12px;">#{escape_html(suggestion.reason)}</p>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp escape_html(nil), do: ""

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(text), do: escape_html(to_string(text))

  defp schedule_email_send do
    # Calculate time until next 7 AM UTC
    now = NaiveDateTime.utc_now()

    target_time_today = %NaiveDateTime{
      now
      | hour: @email_time_hour,
        minute: @email_time_minute,
        second: 0,
        microsecond: {0, 0}
    }

    target_time =
      if NaiveDateTime.compare(now, target_time_today) == :lt do
        # If current time is before 7 AM today, schedule for today at 7 AM
        target_time_today
      else
        # Otherwise, schedule for tomorrow at 7 AM
        tomorrow_date = Date.add(NaiveDateTime.to_date(now), 1)
        NaiveDateTime.new!(tomorrow_date, Time.new!(@email_time_hour, @email_time_minute, 0))
      end

    delay_seconds = NaiveDateTime.diff(target_time, now)

    # Ensure delay is not negative (shouldn't happen with above logic, but as a safeguard)
    delay_seconds = max(0, delay_seconds)

    Logger.info(
      "Next daily email send scheduled in #{delay_seconds} seconds (at #{target_time} UTC)."
    )

    Process.send_after(self(), :send_daily_emails, delay_seconds * 1000)
  end
end

defmodule GroceryPlanner.Notifications.EmailScheduler do
  use GenServer

  alias GroceryPlanner.Notifications.NotificationPreference
  alias GroceryPlanner.Notifications.ExpirationAlerts
  alias GroceryPlanner.Notifications.RecipeSuggestions
  alias GroceryPlanner.Mailer
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

  # TODO: Implement actual rendering of email content
  defp render_email_content(user, account, expiration_summary, recipe_suggestions, days_threshold) do
    # For now, a simple text-based content. This will be replaced with proper HTML rendering.
    body = """
    <h1>Hello #{user.name},</h1>

    <p>Here's your daily Grocery Planner digest for #{Date.utc_today()}.</p>

    <h2>Expiration Alerts</h2>
    <p>You have items expiring soon in your household '#{account.name}'.</p>
    <ul>
      <li>Expired: #{expiration_summary.expired_count}</li>
      <li>Expiring Today: #{expiration_summary.today_count}</li>
      <li>Expiring Tomorrow: #{expiration_summary.tomorrow_count}</li>
      <li>Expiring This Week (within #{days_threshold} days): #{expiration_summary.this_week_count}</li>
      <li>Expiring Soon (within #{days_threshold} days): #{expiration_summary.soon_count}</li>
    </ul>

    <h2>Recipe Suggestions</h2>
    <p>Here are some recipes that can help you use up expiring ingredients:</p>
    <ul>
    #{Enum.map_join(recipe_suggestions, "\n", fn s -> "<li>#{s.recipe.name} (Score: #{s.score}, #{s.reason})</li>" end)}
    </ul>

    <p>Log in to your Grocery Planner account for more details.</p>

    <p>Best regards,</p>
    <p>The Grocery Planner Team</p>
    """

    {:ok, body}
  end

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

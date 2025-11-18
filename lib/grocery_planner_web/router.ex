defmodule GroceryPlannerWeb.Router do
  use GroceryPlannerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GroceryPlannerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug GroceryPlannerWeb.Auth, :fetch_current_user
  end

  pipeline :require_authenticated_user do
    plug GroceryPlannerWeb.Auth, :require_authenticated_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GroceryPlannerWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/sign-up", Auth.SignUpLive
    live "/sign-in", Auth.SignInLive
    post "/auth/sign-in", AuthController, :sign_in
    delete "/auth/sign-out", AuthController, :sign_out
  end

  scope "/", GroceryPlannerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/dashboard", DashboardLive
    live "/settings", SettingsLive
    live "/inventory", InventoryLive
    live "/recipes", RecipesLive
    live "/recipes/search", RecipeSearchLive
    live "/recipes/new", RecipeFormLive, :new
    live "/recipes/:id/edit", RecipeFormLive, :edit
    live "/recipes/:id", RecipeShowLive
    live "/meal-planner", MealPlannerLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", GroceryPlannerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:grocery_planner, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GroceryPlannerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

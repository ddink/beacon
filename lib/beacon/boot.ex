defmodule Beacon.Boot do
  @moduledoc false

  # Initialized all the required data and components for site
  # so it doesn't crash on initial requests nor display unstyled pages or error pages.

  use GenServer, restart: :transient
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def init(%{site: site, skip_boot?: true}) do
    Logger.debug("Beacon.Boot is disabled on site #{site}")

    # Router helpers are always available
    Beacon.Loader.reload_routes_module(site)

    :ignore
  end

  def init(config), do: do_init(config)

  def do_init(config) do
    Logger.info("Beacon.Boot booting site #{config.site}")

    task_supervisor = Beacon.Registry.via({config.site, TaskSupervisor})

    # Sigils and router helpers
    Beacon.Loader.reload_routes_module(config.site)

    # Layouts and pages depend on the components module so we need to load it first
    Beacon.Loader.populate_default_components(config.site)
    Beacon.Loader.reload_components_module(config.site)

    Beacon.Loader.populate_default_layouts(config.site)

    # Pages depend on default layouts
    Beacon.Loader.populate_default_error_pages(config.site)
    Beacon.Loader.populate_default_home_page(config.site)

    assets = [
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_runtime_js(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_runtime_css(config.site) end)
    ]

    modules = [
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_stylesheet_module(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_snippets_module(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_live_data_module(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_layouts_modules(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_error_page_module(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_pages_modules(config.site, per_page: 20) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_info_handlers_module(config.site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_event_handlers_module(config.site) end)
      # TODO: load main pages (order_by: path, per_page: 10) to avoid SEO issues
    ]

    Task.await_many(modules, :timer.minutes(10))

    # TODO: revisit this timeout after we upgrade to Tailwind v4
    Task.await_many(assets, :timer.minutes(5))

    # Reset option to enable event broadcasting even after booting manually
    Beacon.Config.update_value(config.site, :skip_boot?, false)

    # TODO: add telemetry to measure booting time
    Logger.info("Beacon.Boot finished booting site #{config.site}")

    :ignore
  end
end

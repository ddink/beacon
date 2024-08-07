defmodule Beacon.Migration do
  @moduledoc """
  Functions which can be called in an Ecto migration for Beacon installation and upgrades.

  ## Usage

  To install Beacon, you'll need to generate an `Ecto.Migration` that wraps calls to `Beacon.Migration`:

  ```
  mix ecto.gen.migration create_beacon_tables
  ```

  Open the generated migration in your editor and either call or delegate to `up/0` and `down/0`:

  ```elixir
  defmodule MyApp.Repo.Migrations.CreateBeaconTables do
    use Ecto.Migration
    def up, do: Beacon.Migration.up()
    def down, do: Beacon.Migration.down()
  end
  ```

  Then, run the migrations for your app to create the necessary Beacon tables in your database:

  ```
  mix ecto.migrate
  ```

  Note that `up/0` will always execute all migration steps from the initial version to the latest version,
  and those migration are idempotent.

  Check out the [your first site](https://hexdocs.pm/beacon/your-first-site.html) guide for a full example.

  """

  # TODO: `up/1` should execute all migrations from v001 up to `@latest`
  @latest Beacon.Migrations.V001

  @doc """
  Run the `up` changes for all migrations between the initial version and the current version.
  """
  def up do
    @latest.up()
  end

  @doc """
  Run the `down` changes for all migrations between the initial version and the current version.
  """
  def down do
    @latest.down()
  end
end

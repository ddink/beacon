defmodule Beacon.RuntimeCSS.TailwindCompilerTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site

  import ExUnit.CaptureIO
  alias Beacon.RuntimeCSS.TailwindCompiler

  defp create_page(_) do
    beacon_stylesheet_fixture()

    beacon_component_fixture(
      template: ~S"""
      <li id={"my-component-#{@val}"}>
        <span class="text-gray-50"><%= @val %></span>
      </li>
      """
    )

    layout =
      beacon_published_layout_fixture(
        template: """
        <header class="text-gray-100">Page header</header>
        <%= @inner_content %>
        """
      )

    beacon_published_page_fixture(
      layout_id: layout.id,
      path: "/tailwind-test",
      template: """
      <main>
        <h2 class="text-gray-200">Some Values:</h2>
      </main>
      """
    )

    beacon_published_page_fixture(
      layout_id: layout.id,
      path: "/tailwind-test-post-process",
      template: """
      <main>
        <h2 class="text-gray-200">Some Values:</h2>
      </main>
      """
    )

    beacon_page_fixture(
      layout_id: layout.id,
      path: "/b",
      template: """
      <main>
        <h2 class="text-gray-300">Some Values:</h2>
      </main>
      """
    )

    :ok
  end

  test "config" do
    assert TailwindCompiler.config(default_site()) =~ "export default"
  end

  test "css" do
    assert TailwindCompiler.css(default_site()) =~ ".custom-font-style { @apply font-sans; color: #5e5e5e }"
  end

  describe "compile site" do
    setup [:create_page]

    test "includes classes from all resources" do
      capture_io(fn ->
        assert {:ok, output} = TailwindCompiler.compile(default_site())

        # test/support/templates/*.*ex
        assert output =~ "text-red-50"
        assert output =~ "text-red-100"

        # component, layout and page
        assert output =~ "text-gray-50"
        assert output =~ "text-gray-100"
        assert output =~ "text-gray-200"
      end)
    end

    test "do not include classes from unpublished pages" do
      capture_io(fn ->
        assert {:ok, output} = TailwindCompiler.compile(default_site())

        refute output =~ "text-gray-300"
      end)
    end

    test "fetch post processed page templates" do
      assert {:ok, output} = TailwindCompiler.compile(default_site())
      assert output =~ "text-blue-200"
    end
  end
end

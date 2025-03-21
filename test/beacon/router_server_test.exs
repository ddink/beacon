defmodule Beacon.RouterServerTest do
  use Beacon.DataCase, async: false

  alias Beacon.RouterServer

  setup do
    site = default_site()

    RouterServer.del_pages(site)

    # we aren't passing through PageLive in these tests so we have to manually
    # enable the ErrorHandler and set the site in the Process dictionary
    # (which would normally happen in the LiveView mount)
    Process.put(:__beacon_site__, site)
    Process.flag(:error_handler, Beacon.ErrorHandler)

    on_exit(fn -> RouterServer.del_pages(site) end)

    [site: site]
  end

  describe "lookup by path" do
    test "not existing path", %{site: site} do
      refute RouterServer.lookup_path(site, ["home"])
    end

    test "exact match on static paths", %{site: site} do
      RouterServer.add_page(site, "1", "/")
      RouterServer.add_page(site, "2", "/about")
      RouterServer.add_page(site, "3", "/blog/posts/2020-01-my-post")

      assert {"/", "1"} = RouterServer.lookup_path(site, [])
      assert {"/about", "2"} = RouterServer.lookup_path(site, ["about"])
      assert {"/blog/posts/2020-01-my-post", "3"} = RouterServer.lookup_path(site, ["blog", "posts", "2020-01-my-post"])
    end

    test "multiple dynamic segments", %{site: site} do
      RouterServer.add_page(site, "1", "/users/:user_id/posts/:id/edit")

      assert {"/users/:user_id/posts/:id/edit", "1"} = RouterServer.lookup_path(site, ["users", "1", "posts", "100", "edit"])
    end

    test "dynamic segments lookup in batch", %{site: site} do
      RouterServer.add_page(site, "1", "/:page")
      RouterServer.add_page(site, "2", "/users/:user_id/posts/:id/edit")

      assert {"/:page", "1"} = RouterServer.lookup_path(site, ["home"], 1)
      assert {"/users/:user_id/posts/:id/edit", "2"} = RouterServer.lookup_path(site, ["users", "1", "posts", "100", "edit"], 1)
    end

    test "dynamic segments with same prefix", %{site: site} do
      RouterServer.add_page(site, "1", "/posts/:post_id")
      RouterServer.add_page(site, "2", "/posts/authors/:author_id")

      assert {"/posts/:post_id", "1"} = RouterServer.lookup_path(site, ["posts", "1"])
      assert {"/posts/authors/:author_id", "2"} = RouterServer.lookup_path(site, ["posts", "authors", "1"])
    end

    test "static segments with varied size", %{site: site} do
      RouterServer.add_page(site, "1", "/blog/2020/01/07/hello")
      refute RouterServer.lookup_path(site, ["blog", "2020"])
      refute RouterServer.lookup_path(site, ["blog", "2020", "01", "07"])
      refute RouterServer.lookup_path(site, ["blog", "2020", "01", "07", "hello", "extra"])
    end

    test "catch all", %{site: site} do
      RouterServer.add_page(site, "1", "/posts/*slug")

      assert {"/posts/*slug", "1"} = RouterServer.lookup_path(site, ["posts", "2022", "my-post"])
    end

    test "catch all with existing path with same prefix", %{site: site} do
      RouterServer.add_page(site, "1", "/press/releases/*slug")
      RouterServer.add_page(site, "2", "/press/releases")

      assert {"/press/releases/*slug", "1"} = RouterServer.lookup_path(site, ["press", "releases", "announcement"])
      assert {"/press/releases", "2"} = RouterServer.lookup_path(site, ["press", "releases"])
    end

    test "catch all must match at least 1 segment", %{site: site} do
      RouterServer.add_page(site, "1", "/posts/*slug")

      refute RouterServer.lookup_path(site, ["posts"])
    end

    test "mixed dynamic segments", %{site: site} do
      RouterServer.add_page(site, "1", "/posts/:year/*slug")

      assert {"/posts/:year/*slug", "1"} = RouterServer.lookup_path(site, ["posts", "2022", "my-post"])
    end
  end

  test "add page on page_loaded event", %{site: site} do
    %{id: page_id} = page = Beacon.Test.Fixtures.beacon_published_page_fixture(path: "/test/router/add")
    RouterServer.del_pages(site)

    server = site |> Beacon.RouterServer.name() |> GenServer.whereis()
    send(server, {:page_loaded, page})

    assert %Beacon.Content.Page{id: ^page_id} = Beacon.RouterServer.lookup_page!(site, ["test", "router", "add"])
  end
end

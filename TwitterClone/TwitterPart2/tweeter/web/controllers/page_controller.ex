defmodule Tweeter.PageController do
  use Tweeter.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end

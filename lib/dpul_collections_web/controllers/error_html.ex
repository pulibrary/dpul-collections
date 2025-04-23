defmodule DpulCollectionsWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use DpulCollectionsWeb, :html
  use Gettext, backend: DpulCollectionsWeb.Gettext
  # If you want to customize your error pages,
  # add pages to the error directory, e.g.:
  #
  #   * lib/dpul_collections_web/controllers/error_html/404.html.heex
  #   * lib/dpul_collections_web/controllers/error_html/500.html.heex
  #
  # they are used via the embed_templates/1 call below
  embed_templates "error_html/*"

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

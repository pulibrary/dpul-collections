defmodule DpulCollectionsWeb.PaneComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "z-3 bg-background min-w-full min-h-full col-start-1 row-start-1 absolute top-0 dismissable",
        @translate,
        @class
      ]}
      phx-mounted={
        JS.transition({"ease-out duration-250", @translate, "translate-x-0"})
        |> hide_covered_elements()
      }
      phx-remove={show_covered_elements()}
      data-cancel={JS.patch(@cancel_url, replace: true)}
      phx-window-keydown={JS.exec("data-cancel", to: "##{@id}.dismissable")}
      phx-key="escape"
      phx-hook="ScrollTop"
    >
      <div id="viewer-header" class="header-x-padding heading-y-padding bg-accent flex flex-row">
        <div class="flex-auto flex flex-row gap-4">
          {render_slot(@heading)}
        </div>
        <.link
          aria-label={gettext("close pane")}
          class="flex-none cursor-pointer justify-end"
          patch={@cancel_url}
          replace
        >
          <.icon class="w-8 h-8" name="hero-x-mark" />
        </.link>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Hide elements that get covered by the viewer modal so they're not tab
  # targetable.
  def hide_covered_elements(js \\ %JS{}) do
    [".cover-with-pane"]
    |> Enum.reduce(js, fn selector, acc_js ->
      JS.hide(acc_js, to: selector, transition: "fade-out-scale", time: 250)
    end)
  end

  def show_covered_elements(js \\ %JS{}) do
    [".cover-with-pane"]
    |> Enum.reduce(js, fn selector, acc_js -> JS.show(acc_js, to: selector) end)
  end
end

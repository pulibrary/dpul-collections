defmodule DpulCollectionsWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import Iconify

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/tailwind_heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(assigns) do
    ~H"""
    <.iconify class={@class} icon={@name} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders a standard content separator. We use this to separate several section
  - in mockups it's the orange bar between things.
  ## Examples
      <.content_separator />
  """
  attr :rest, :global, default: %{class: ""}

  def content_separator(assigns) do
    ~H"""
    <hr class={"h-1 border-0 bg-accent #{@rest.class}"} {@rest} />
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :href, :string, default: nil, doc: "link - if set it makes an anchor tag"
  attr :patch, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(replace), doc: "the arbitrary HTML attributes to add link"

  def primary_button(assigns = %{href: href, patch: patch}) when href != nil or patch != nil do
    ~H"""
    <.link href={@href} patch={@patch} class={["btn-primary", "flex gap-2 p-x-2", @class]} {@rest}>
      <div>
        {render_slot(@inner_block)}
      </div>
    </.link>
    """
  end

  def primary_button(assigns) do
    ~H"""
    <button class={["btn-primary flex gap-2 p-4", @class]} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, required: true
  attr :class, :string, default: nil

  slot :tab, required: true do
    attr :class, :string
    attr :active, :boolean
  end

  slot :panel, required: false do
    attr :class, :string
  end

  def tabs(assigns) do
    active_index =
      Enum.find_index(assigns.tab, &Map.get(&1, :active)) || 0

    assigns = assign(assigns, :active_index, active_index + 1)

    ~H"""
    <div id={@id}>
      <div role="tablist" class={["flex gap-4", @class]}>
        <.primary_button
          :for={{tab, index} <- Enum.with_index(@tab, 1)}
          id={"#{@id}-tab-header-#{index}"}
          phx-show-tab={hide_tab(@id, length(@tab)) |> show_tab(@id, index)}
          phx-click={JS.exec("phx-show-tab", to: "##{@id}-tab-header-#{index}")}
          phx-mounted={tab[:active] && JS.exec("phx-show-tab", to: "##{@id}-tab-header-#{index}")}
          role="tab"
          aria-selected={@active_index == index}
          aria-controls={"#{@id}-tab-panel-#{index}"}
          tabindex={(@active_index == index && "0") || "-1"}
          class={[
            tab[:class],
            "flex-grow"
          ]}
        >
          {render_slot(tab)}
        </.primary_button>
      </div>
      <div>
        <div
          :for={{panel, index} <- Enum.with_index(@panel, 1)}
          id={"#{@id}-tab-panel-#{index}"}
          aria-labelledby={"#{@id}-tab-header-#{index}"}
          role="tabpanel"
          class={[
            "tab-content w-full py-4",
            "[&:not(.active-panel)]:hidden",
            "[&.active-panel]:block",
            panel[:class]
          ]}
        >
          {render_slot(panel)}
        </div>
      </div>
    </div>
    """
  end

  # coveralls-ignore-start
  # Ignore coverage for this because for some reason ExCoveralls is having a
  # hard time noticing it being called.
  def hide_tab(js \\ %JS{}, id, count) do
    Enum.reduce(1..count, js, fn item, acc ->
      acc
      |> JS.remove_class("active", to: "##{id}-tab-header-#{item}")
      |> JS.remove_class("active-panel", to: "##{id}-tab-panel-#{item}")
      |> JS.set_attribute({"aria-selected", "false"}, to: "##{id}-tab-header-#{item}")
    end)
  end

  # coveralls-ignore-stop

  def show_tab(js \\ %JS{}, id, count) when is_binary(id) do
    js
    |> JS.add_class("active", to: "##{id}-tab-header-#{count}")
    |> JS.add_class("active-panel", to: "##{id}-tab-panel-#{count}")
    |> JS.set_attribute({"aria-selected", "true"}, to: "##{id}-tab-header-#{count}")
  end
end

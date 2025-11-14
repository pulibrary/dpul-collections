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
      phx-connected={show("##{@id}")}
      phx-mounted={show("##{@id}")}
      class={[
        "hidden fixed top-20 right-2 mr-2 w-80 sm:w-96 zi-flash rounded-lg p-3 ring-1",
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
    <div id={@id} role="alert">
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
    <hr aria-hidden="true" class={"h-1 border-0 bg-accent #{@rest.class}"} {@rest} />
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :href, :string, default: nil, doc: "link - if set it makes an anchor tag"
  attr :patch, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :navigate, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :disabled, :boolean, default: false

  attr :rest, :global,
    include: ~w(replace disabled form name value),
    doc: "the arbitrary HTML attributes to add link"

  def primary_button(assigns = %{href: href, patch: patch, navigate: navigate})
      when href != nil or patch != nil or navigate != nil do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "disabled",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    <.link
      :if={!@disabled}
      href={@href}
      patch={@patch}
      navigate={@navigate}
      class={["btn-primary", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def primary_button(assigns) do
    ~H"""
    <button class={["btn-primary", @class]} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :navigate, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :aria_label, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(replace), doc: "the arbitrary HTML attributes to add link"

  def transparent_button(assigns = %{navigate: navigate}) when navigate != nil do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "disabled",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    <.link
      :if={!@disabled}
      navigate={@navigate}
      aria-label={@aria_label}
      class={["btn-transparent align-content", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def transparent_button(assigns) do
    ~H"""
    <button class={["btn-transparent", @class]} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :href, :string, default: nil, doc: "link - if set it makes an anchor tag"
  attr :patch, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(replace), doc: "the arbitrary HTML attributes to add link"

  def secondary_button(assigns = %{href: href, patch: patch}) when href != nil or patch != nil do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "btn-secondary",
        "disabled",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    <.link :if={!@disabled} href={@href} patch={@patch} class={["btn-secondary", @class]} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def secondary_button(assigns) do
    ~H"""
    <button disabled={@disabled} class={["btn-secondary", @class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :href, :string, default: nil, doc: "link - if set it makes an anchor tag"
  attr :patch, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(replace), doc: "the arbitrary HTML attributes to add link"

  def danger_button(assigns = %{href: href, patch: patch}) when href != nil or patch != nil do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "btn-danger",
        "disabled",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    <.link :if={!@disabled} href={@href} patch={@patch} class={["btn-danger", @class]} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def danger_button(assigns) do
    ~H"""
    <button class={["btn-danger", @class]} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :patch, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(replace), doc: "the arbitrary HTML attributes to add link"

  def arrow_button_left(assigns = %{patch: patch}) when patch != nil do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "left-arrow-box",
        "disabled",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    <.link :if={!@disabled} patch={@patch} class={["h-14 btn-transparent", @class]} {@rest}>
      <div class="left-arrow-box">
        {render_slot(@inner_block)}
      </div>
    </.link>
    """
  end

  slot :inner_block
  attr :class, :any, default: nil
  attr :patch, :string, default: nil, doc: "link - if set makes an anchor tag"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(replace), doc: "the arbitrary HTML attributes to add link"

  def arrow_button_right(assigns = %{patch: patch}) when patch != nil do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "right-arrow-box hover:opacity-50",
        "disabled",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    <.link :if={!@disabled} patch={@patch} class={["h-14 btn-transparent", @class]} {@rest}>
      <div class="right-arrow-box">
        {render_slot(@inner_block)}
      </div>
    </.link>
    """
  end

  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :patch, :string, default: nil
  attr :icon, :string, default: nil
  attr :button_text, :string, default: nil
  attr :aria_label, :string, default: nil

  def icon_button(assigns) do
    ~H"""
    <span
      :if={@disabled}
      class={[
        "btn-icon",
        "disabled",
        @class
      ]}
    >
      <.icon name={@icon} class="mt-1 h-8 w-8 icon" />
      <div class="mt-[-.25rem]">{@button_text}</div>
    </span>
    <.link
      :if={!@disabled}
      href={@href}
      patch={@patch}
      navigate={@navigate}
      aria-label={@aria_label}
      class={["btn-icon", @class]}
    >
      <.icon name={@icon} class="mt-1 h-8 w-8 icon" />
      <div class="mt-[-.25rem]">{@button_text}</div>
    </.link>
    """
  end

  attr :properties, :map, default: %{}

  def meta_properties(assigns) do
    ~H"""
    <meta
      :for={{property_key, property_value} <- @properties}
      property={property_key}
      content={property_value}
    />
    """
  end

  attr :id, :string, required: true
  attr :afterClose, :any, required: false, default: %JS{}
  attr :label, :string, required: true
  attr :subtitle, :string, required: false, default: nil

  slot :inner_block, doc: "the modal content"

  def modal(assigns) do
    ~H"""
    <dialog
      id={@id}
      phx-hook="Dialog"
      phx-mounted={
        # Ignore `open` attribute when LiveView updates so JS can control opening/closing the modal.
        JS.ignore_attributes("open")
      }
      dcjs-open={JS.dispatch("dpulc:showDialog")}
      dcjs-close={JS.dispatch("dpulc:closeDialog") |> JS.exec("dcjs-after-close")}
      dcjs-after-close={@afterClose}
      aria-labelledby={"#{@id}-label"}
      closedBy="any"
      class="modal max-w-2xl backdrop:bg-black/50 open:fixed open:top-[50%] open:left-[50%] open:-translate-x-[50%] open:-translate-y-[50%] fixed bg-white rounded-lg shadow-sm text-dark-text"
    >
      <div class="w-full max-w-2xl bg-white shadow-lg rounded-lg p-8 relative">
        <!-- Modal header -->
        <div class="flex items-start justify-between border-b border-gray-300 pb-3">
          <div class="flex flex-col">
            <h2 id={"#{@id}-label"} class="text-xl font-semibold">
              {@label}
            </h2>

            <p :if={@subtitle} class="text-lg">
              {@subtitle}
            </p>
          </div>
          <button
            type="button"
            class="cursor-pointer"
            phx-click={JS.exec("dcjs-close", to: {:closest, "dialog"})}
          >
            <.icon name="hero-x-mark" />
            <span class="sr-only">{gettext("Close modal")}</span>
          </button>
        </div>
        {render_slot(@inner_block)}
      </div>
    </dialog>
    """
  end

  # @doc """
  # Renders a simple form.
  #
  # ## Examples
  #
  # <.simple_form for={@form} phx-change="validate" phx-submit="save">
  #   <.input field={@form[:email]} label="Email"/>
  #   <.input field={@form[:username]} label="Username" />
  #   <:actions>
  #     <.button>Save</.button>
  #   </:actions>
  # </.simple_form>
  # """
  # attr :for, :any, required: true, doc: "the datastructure for the form"
  # attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  #
  # attr :rest, :global,
  #   include: ~w(autocomplete name rel action enctype method novalidate target multipart),
  #   doc: "the arbitrary HTML attributes to apply to the form tag"
  #
  # slot :inner_block, required: true
  # slot :actions, doc: "the slot for form actions, such as a submit button"
  #
  # def simple_form(assigns) do
  #   ~H"""
  #   <.form :let={f} for={@for} as={@as} {@rest}>
  #     <div class="mt-10 space-y-8 bg-white">
  #       {render_slot(@inner_block, f)}
  #       <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
  #         {render_slot(action, f)}
  #       </div>
  #     </div>
  #   </.form>
  #   """
  # end

  # @doc """
  # Renders a button.
  #
  # ## Examples
  #
  # <.button>Send!</.button>
  # <.button phx-click="go" class="ml-2">Send!</.button>
  # """
  # attr :type, :string, default: nil
  # attr :class, :string, default: nil
  # attr :rest, :global, include: ~w(disabled form name value)
  #
  # slot :inner_block, required: true
  #
  # def button(assigns) do
  #   ~H"""
  #   <button
  #     type={@type}
  #     class={[
  #       "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3",
  #       "text-sm font-semibold leading-6 text-white active:text-white/80",
  #       @class
  #     ]}
  #     {@rest}
  #   >
  #     {render_slot(@inner_block)}
  #   </button>
  #   """
  # end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

  * You may also set `type="select"` to render a `<select>` tag

  * `type="checkbox"` is used exclusively to render boolean values

  * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
        range search select tel text textarea time url week checkgroup)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
        multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  # Adds support for a group of checkboxes representing options for a field.
  # See https://fly.io/phoenix-files/making-a-checkboxgroup-input/ for
  # inspiration.
  def input(%{type: "checkgroup"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <label
        :for={{label, value} <- @options}
        class="flex items-center gap-2 cursor-pointer"
      >
        <input
          type="checkbox"
          id={"#{@name}-#{value}"}
          name={@name}
          value={value}
          checked={is_list(@value) && value in (@value || [])}
          multiple={true}
          class="h-[20px] w-[20px]"
          {@rest}
        />
        {label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # def input(%{type: "checkbox"} = assigns) do
  #   assigns =
  #     assign_new(assigns, :checked, fn ->
  #       Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
  #     end)
  #
  #   ~H"""
  #   <div phx-feedback-for={@name}>
  #     <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
  #       <input type="hidden" name={@name} value="false" />
  #       <input
  #         type="checkbox"
  #         id={@id}
  #         name={@name}
  #         value="true"
  #         checked={@checked}
  #         class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
  #         {@rest}
  #       />
  #       {@label}
  #     </label>
  #     <.error :for={msg <- @errors}>{msg}</.error>
  #   </div>
  #   """
  # end
  #
  # def input(%{type: "select"} = assigns) do
  #   ~H"""
  #   <div phx-feedback-for={@name}>
  #     <.label for={@id}>{@label}</.label>
  #     <select
  #       id={@id}
  #       name={@name}
  #       class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
  #       multiple={@multiple}
  #       {@rest}
  #     >
  #       <option :if={@prompt} value="">{@prompt}</option>
  #       {Phoenix.HTML.Form.options_for_select(@options, @value)}
  #     </select>
  #     <.error :for={msg <- @errors}>{msg}</.error>
  #   </div>
  #   """
  # end
  #
  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class={@class} phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "block w-full text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <div class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1>
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-lg">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </div>
    """
  end

  def card_button(assigns) do
    ~H"""
    <.primary_button
      class="btn-base border-1 border-gray-200 bg-background py-1 px-2 flex flex-col items-center zi-card-button hover:bg-background"
      {assigns}
    >
      <.icon class="grow w-[1.5rem] h-[1.5rem]" name={@icon} />
      <span class="text-sm font-normal normal-case">
        {@label}
      </span>
    </.primary_button>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(DpulCollectionsWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(DpulCollectionsWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end

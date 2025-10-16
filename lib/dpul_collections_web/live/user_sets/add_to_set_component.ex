defmodule DpulCollectionsWeb.UserSets.AddToSetComponent do
  alias DpulCollections.UserSets.SetItem
  alias DpulCollections.UserSets.Set
  alias DpulCollections.UserSets
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> reset()
    }
  end

  attr :item_id, :string, default: nil
  attr :current_scope, :any
  attr :mode, :string, default: "append"

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id="add-set-modal"
        label="Save to Set"
      >
        <div id="add-set-modal-content" class="min-w-[400px] mt-4 w-full flex">
          <.append :if={@mode == "append"} {assigns} />
          <.new_set_form :if={@mode == "new_set"} {assigns} />
        </div>
      </.modal>
    </div>
    """
  end

  def new_set_form(assigns) do
    ~H"""
    <.form
      for={@set_form}
      class="flex flex-col gap-2 w-full"
      phx-submit="save_new_set"
      phx-target={@myself}
    >
      <.input type="text" required={true} label="Set name" field={@set_form[:title]} />
      <.input type="textarea" label="Set description" field={@set_form[:description]} />
      <.inputs_for :let={si_form} field={@set_form[:set_items]}>
        <input type="hidden" name={si_form[:solr_id].name} value={si_form[:solr_id].value} />
      </.inputs_for>
      <div class="flex w-full">
        <.secondary_button phx-click="reset" phx-target={@myself}>
          Cancel
        </.secondary_button>
        <div class="grow"></div>
        <.primary_button>
          Create Set
        </.primary_button>
      </div>
    </.form>
    """
  end

  def append(assigns) do
    ~H"""
    <div class="w-full flex flex-col gap-2">
      <.primary_button
        phx-click="create_set"
        phx-target={@myself}
        class="w-full text-left"
      >
        <span class="grow">
          Create new set
        </span>
      </.primary_button>
      <ul class="flex flex-col gap-2">
        <li :for={set <- @sets} class={["group", set.has_solr_id && "has-item"]}>
          <.secondary_button
            class="group-[.has-item]:bg-loud-button group-[.has-item]:text-light-text group-[.has-item]:hover:text-dark-text w-full flex text-left items-left justify-left"
            phx-target={@myself}
            phx-click="append_item"
            phx-value-set-id={set.id}
          >
            <span class="grow">
              {set.title} - {set.set_item_count} Items
            </span>
            <.icon :if={set.has_solr_id} name="hero-check-circle" />
          </.secondary_button>
        </li>
      </ul>
    </div>
    """
  end

  def handle_event(
        "append_item",
        %{"set-id" => set_id},
        socket = %{assigns: %{current_scope: current_scope, item_id: solr_id}}
      ) do
    set = UserSets.get_set!(current_scope, set_id)
    {:ok, _set_item} = UserSets.create_set_item(%{set_id: set.id, solr_id: solr_id})
    {:noreply, socket |> reset()}
  end

  def handle_event(
        "save_new_set",
        %{"set" => params},
        socket = %{assigns: %{current_scope: current_scope}}
      ) do
    case UserSets.create_set(current_scope, params) do
      {:ok, _set} ->
        {:noreply,
         socket
         |> reset()}

      {:error, %Ecto.Changeset{} = changeset} ->
        dbg(changeset)
        {:noreply, assign(socket, new_set_form: to_form(changeset))}
    end
  end

  def handle_event(
        "create_set",
        _params,
        socket = %{assigns: %{current_scope: current_scope, item_id: item_id}}
      ) do
    {
      :noreply,
      socket
      |> assign(
        :set_form,
        to_form(
          UserSets.change_set(current_scope, %Set{
            user_id: current_scope.user.id,
            set_items: [%SetItem{solr_id: item_id}]
          })
        )
      )
      |> assign(:mode, "new_set")
    }
  end

  def handle_event("open_modal", %{"item_id" => item_id}, socket) do
    {:noreply,
     socket
     |> assign(:item_id, item_id)
     |> reset()
     # Notes to self:
     # We can get rid of a bunch of this Modal stuff with
     # JS.ignore_attribute on phx-mounted
     |> push_event("dcjs-open", %{id: "add-set-modal"})}
  end

  def handle_event("reset", _, socket) do
    {:noreply,
     socket
     |> reset()}
  end

  def reset(socket) do
    socket
    |> assign(:mode, "append")
    |> assign(
      :sets,
      UserSets.list_user_sets_for_addition(socket.assigns.current_scope, socket.assigns[:item_id])
    )
  end

  attr :item_id, :string, required: true

  def add_button(assigns) do
    ~H"""
    <.card_button
      icon="hero-folder-plus"
      label={gettext("Save")}
      phx-click="open_modal"
      phx-value-item_id={@item_id}
      phx-target="#add-set-modal"
    />
    """
  end
end

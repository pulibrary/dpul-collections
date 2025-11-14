defmodule DpulCollectionsWeb.UserSets.AddToSetComponent do
  alias DpulCollections.Item
  alias DpulCollections.Solr
  alias DpulCollections.UserSets.SetItem
  alias DpulCollections.UserSets.Set
  alias DpulCollections.UserSets
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  # Called by live_component when this spins up - use it to pre-populate
  # starting state via #display_list_sets().
  def update(%{item_id: item_id}, socket) when not is_nil(item_id) do
    item = Solr.find_by_id(item_id) |> Item.from_solr()

    {:ok,
     socket
     |> assign(:item_id, item_id)
     |> assign(:item_title, item.title)
     |> display_list_sets()
     |> push_event("dcjs-open", %{id: "add-set-modal"})}
  end

  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> display_list_sets()
    }
  end

  attr :item_id, :string, default: nil
  attr :item_title, :string, default: nil
  attr :current_scope, :any
  attr :current_path, :string, required: true

  attr :mode, :atom,
    doc: "a signifier for which part of the add to set modal to show",
    values: [:list_sets, :new_set],
    default: :list_sets

  @doc """
  Displays a modal to allow adding a given Item ID to a user's Set.
  There are two modes:
    - list_sets (Lists all a user's sets, allows a user to click any to add that item or click 'Create New Set')
    - new_set (Create a new set and add the item to it)
  """
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal
        :if={Application.fetch_env!(:dpul_collections, :feature_account_toolbar)}
        id="add-set-modal"
        label="Save to Set"
        subtitle={"Adding #{@item_title}"}
        afterClose={JS.patch(redirect_path(@current_path, nil))}
      >
        <div id="add-set-modal-content" class="min-w-[400px] mt-4 w-full flex">
          <.list_sets :if={@mode == :list_sets} {assigns} />
          <.new_set :if={@mode == :new_set} {assigns} />
        </div>
      </.modal>
    </div>
    """
  end

  @doc """
  Resets the modal back to list_sets view.
  """
  def display_list_sets(socket) do
    socket
    |> assign(:mode, :list_sets)
    |> assign(
      :sets,
      UserSets.list_user_sets_for_addition(socket.assigns.current_scope, socket.assigns[:item_id])
    )
  end

  @doc """
  List a user's sets and allow them to append the item to one - or click to create a new one.
  If the item's already in the set clicked then it removes it.
  """
  def list_sets(assigns) do
    ~H"""
    <div class="w-full flex flex-col gap-2">
      <.primary_button
        phx-click="display_new_set_form"
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
            phx-click="toggle_set_membership"
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

  @doc """
  Displays a form to create a new set for the item to be in.
  """
  def new_set(assigns) do
    ~H"""
    <.form
      for={@set_form}
      class="flex flex-col gap-2 w-full"
      phx-submit="create_set"
      phx-target={@myself}
    >
      <.input type="text" required={true} label="Set name" field={@set_form[:title]} />
      <.input type="textarea" label="Set description" field={@set_form[:description]} />
      <.inputs_for :let={si_form} field={@set_form[:set_items]}>
        <input type="hidden" name={si_form[:solr_id].name} value={si_form[:solr_id].value} />
      </.inputs_for>
      <div class="flex w-full">
        <.secondary_button phx-click="display_list_sets" phx-target={@myself}>
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

  def handle_event(
        "toggle_set_membership",
        %{"set-id" => set_id},
        socket = %{assigns: %{current_scope: current_scope, item_id: solr_id}}
      ) do
    set = UserSets.get_set!(current_scope, set_id)

    case UserSets.get_set_item(set.id, solr_id) do
      # If there isn't one yet, make one.
      nil ->
        {:ok, _set_item} =
          UserSets.create_set_item(current_scope, %{set_id: set.id, solr_id: solr_id})

      # Otherwise delete the existing one.
      set_item ->
        {:ok, _} = UserSets.delete_set_item(current_scope, set_item)
    end

    {:noreply, socket |> display_list_sets()}
  end

  def handle_event(
        "create_set",
        %{"set" => params},
        socket = %{assigns: %{current_scope: current_scope}}
      ) do
    case UserSets.create_set(current_scope, params) do
      {:ok, _set} ->
        {:noreply,
         socket
         |> display_list_sets()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, new_set_form: to_form(changeset))}
    end
  end

  def handle_event(
        "display_new_set_form",
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
      |> assign(:mode, :new_set)
    }
  end

  def handle_event("display_list_sets", _, socket) do
    {:noreply,
     socket
     |> display_list_sets()}
  end

  attr :item_id, :string,
    doc: "Item ID to be added to a user set if this button is clicked. Should be a Solr ID.",
    required: true

  attr :current_scope, :map, required: false, default: nil
  attr :current_path, :string, required: true

  @doc """
  Function component that triggers the add to set modal for a given Item ID when it's clicked.
  """
  def add_button(assigns = %{current_scope: %{}}) do
    ~H"""
    <.card_button
      :if={Application.fetch_env!(:dpul_collections, :feature_account_toolbar)}
      icon="hero-folder-plus"
      label={gettext("Save")}
      patch={redirect_path(@current_path, @item_id)}
    />
    """
  end

  def add_button(assigns = %{current_scope: nil}) do
    ~H"""
    <.card_button
      :if={Application.fetch_env!(:dpul_collections, :feature_account_toolbar)}
      icon="hero-folder-plus"
      label={gettext("Save")}
      navigate={~p"/users/log-in?#{%{return_to: redirect_path(@current_path, @item_id)}}"}
    />
    """
  end

  def redirect_path(url, nil) do
    uri = URI.parse(url)

    query =
      uri.query
      |> URI.decode_query()
      |> Map.delete("save_item")
      |> URI.encode_query()

    "#{uri.path}#{query && "?"}#{query}"
  end

  def redirect_path(url, item_id) do
    uri = URI.parse(url)

    query =
      uri.query
      |> URI.decode_query()
      |> Map.put("save_item", item_id)
      |> URI.encode_query()

    "#{uri.path}?#{query}"
  end
end

defmodule AndrewWeb.ClientLive.New do
  use AndrewWeb, :live_view
  alias Andrew.Domain.Invoicing.Client

  def mount(_params, _session, socket) do
    actor = %{role: "admin"}

    form =
      Client
      |> AshPhoenix.Form.for_create(:create, actor: actor)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "New Client")
      |> assign(form: form)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl">
      <div class="mb-6">
        <h1 class="text-2xl font-semibold text-gray-900">Add New Client</h1>
        <p class="mt-2 text-sm text-gray-600">Create a new client record.</p>
      </div>

      <div class="bg-white shadow rounded-lg p-6">
        <.simple_form for={@form} phx-submit="save">
          <.input field={@form[:name]} type="text" label="Client Name" required />
          <.input field={@form[:license_no]} type="text" label="License Number" required />
          <.input field={@form[:address]} type="textarea" label="Address" required />
          <.input field={@form[:phone_number]} type="tel" label="Phone Number" />
          <.input field={@form[:email]} type="email" label="Email" />

          <:actions>
            <.button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white">
              Create Client
            </.button>
            <.link
              navigate={~p"/clients"}
              class="ml-3 bg-gray-200 hover:bg-gray-300 text-gray-700 px-4 py-2 rounded-md text-sm font-medium"
            >
              Cancel
            </.link>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client created successfully")
         |> push_navigate(to: ~p"/clients")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end
end

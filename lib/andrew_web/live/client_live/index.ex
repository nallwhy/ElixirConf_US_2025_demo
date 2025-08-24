defmodule AndrewWeb.ClientLive.Index do
  use AndrewWeb, :live_view

  alias Andrew.Domain.Invoicing

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Clients")
      |> load_clients()

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-semibold text-gray-900">Clients</h1>
        <button class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium">
          Add Client
        </button>
      </div>

      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">All Clients</h3>
        </div>
        <div class="overflow-x-auto">
          <%= if Enum.empty?(@clients) do %>
            <div class="p-6 text-gray-500 text-center py-8">
              No clients yet. Click "Add Client" to get started.
            </div>
          <% else %>
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Name
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    License No
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Address
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for client <- @clients do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {client.name}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {client.license_no}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {client.address}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp load_clients(socket) do
    clients = Invoicing.Client |> Ash.read!()
    assign(socket, :clients, clients)
  end
end

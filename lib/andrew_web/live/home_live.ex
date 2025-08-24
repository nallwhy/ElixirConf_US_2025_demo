defmodule AndrewWeb.HomeLive do
  use AndrewWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl">
      <h1 class="text-2xl font-semibold text-gray-900 mb-6">Dashboard</h1>
      <!-- Content will go here -->
    </div>
    """
  end
end

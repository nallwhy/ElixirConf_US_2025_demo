defmodule AndrewWeb.ChatbotLive do
  use AndrewWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:input, "")
     |> assign(:expanded, false), layout: false}
  end

  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, :expanded, !socket.assigns.expanded)}
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user_message = %{role: :user, content: message}
    messages = socket.assigns.messages ++ [user_message]

    bot_response = %{
      role: :assistant,
      content: "Hello! I'm here to help you with any questions you may have."
    }

    updated_messages = messages ++ [bot_response]

    {:noreply,
     socket
     |> assign(:messages, updated_messages)
     |> assign(:input, "")}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, :input, value)}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed bottom-4 right-4 z-50">
      <%= if @expanded do %>
        <div
          class="bg-white rounded-lg shadow-2xl border border-gray-200 flex flex-col"
          style="width: 30rem; height: 32rem;"
        >
          <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-blue-600 text-white rounded-t-lg">
            <h3 class="font-semibold">AI Assistant</h3>
            <button
              phx-click="toggle_chat"
              class="text-blue-100 hover:text-white"
            >
              ✕
            </button>
          </div>

          <div class="flex-1 p-4 overflow-y-auto space-y-3">
            <%= if Enum.empty?(@messages) do %>
              <div class="text-gray-500 text-sm text-center py-4">
                Hello! How can I help you today?
              </div>
            <% else %>
              <%= for message <- @messages do %>
                <div class={
                  if(message.role == :user, do: "flex justify-end", else: "flex justify-start")
                }>
                  <div class={[
                    "max-w-xs px-3 py-2 rounded-lg text-sm",
                    if(message.role == :user,
                      do: "bg-blue-600 text-white",
                      else: "bg-gray-200 text-gray-800"
                    )
                  ]}>
                    {message.content}
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <div class="p-4 border-t border-gray-200">
            <form phx-submit="send_message" class="flex space-x-2">
              <input
                type="text"
                value={@input}
                phx-change="update_input"
                name="message"
                placeholder="Type your message..."
                class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                autocomplete="off"
              />
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm"
              >
                Send
              </button>
            </form>
          </div>
        </div>
      <% else %>
        <button
          phx-click="toggle_chat"
          class="bg-blue-600 hover:bg-blue-700 text-white rounded-full p-4 shadow-lg"
        >
          💬
        </button>
      <% end %>
    </div>
    """
  end
end

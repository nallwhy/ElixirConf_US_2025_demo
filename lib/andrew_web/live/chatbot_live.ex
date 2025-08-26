defmodule AndrewWeb.ChatbotLive do
  use AndrewWeb, :live_view
  alias Andrew.AI
  alias Andrew.Utils, as: U

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(actor: %{role: "admin"})
      |> assign_agent()
      |> assign(messages: [], new_message: nil, in_progress: false, expanded: false)

    {:ok, socket, layout: false}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <button
        id="chatbot-toggle"
        class="z-[3000] fixed right-4 bottom-8 h-12 w-12 cursor-pointer rounded-full bg-blue-600 p-3 text-white shadow-lg transition-transform duration-200 hover:scale-110"
        phx-click={JS.push("toggle") |> JS.focus(to: "#chatbot-input")}
      >
        💬
      </button>
    </div>
    <div
      id="chatbot-box"
      class={[
        "z-[2000] h-[640px] w-[480px] fixed right-4 bottom-24 hidden flex-col rounded-lg bg-white shadow-lg",
        @expanded && "!flex"
      ]}
    >
      <div class="flex items-center justify-between rounded-t-lg bg-blue-600 p-4 font-bold text-white">
        Andrew
        <div class="space-x-2">
          <button id="chatbot-reset" phx-click={JS.push("reset")}>
            <.icon
              name="hero-arrow-path"
              class="h-6 w-6 cursor-pointer transition-transform duration-200 hover:scale-125"
            />
          </button>
          <button id="chatbot-close" phx-click={JS.push("toggle")}>
            <.icon
              name="hero-chevron-down"
              class="h-6 w-6 cursor-pointer transition-transform duration-200 hover:scale-125"
            />
          </button>
        </div>
      </div>

      <div
        id="chat-log"
        class="mb-4 flex-1 space-y-4 overflow-y-scroll p-4"
        phx-hook="ScrollStickTo"
        data-scroll-to="bottom"
        data-parent-id="chatbot-box"
      >
        <div id="messages" class="space-y-4">
          <.message :for={message <- @messages} message={message} />
        </div>
        <ol>
          <li class="text-left">
            <span class="prose">
              <span :if={@in_progress && !@new_message}>
                <.icon name="hero-arrow-path" class="ml-1 size-4 animate-spin" />
              </span>
              <span :if={@new_message}>{@new_message |> U.Md.html() |> raw()}</span>
            </span>
          </li>
        </ol>
      </div>

      <div class="rounded-lg p-4">
        <form phx-submit="send_message" class="flex flex-col gap-y-2">
          <div class="flex items-center gap-x-2">
            <input
              id="chatbot-input"
              name="message"
              class="flex-1 rounded-lg border-1 p-2"
            />
            <button
              type="submit"
              class="w-24 cursor-pointer rounded bg-blue-500 px-4 py-2 font-bold text-white hover:bg-blue-700 disabled:bg-gray-300"
              disabled={disabled(@in_progress)}
            >
              {if !disabled(@in_progress), do: "Send", else: "..."}
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  def handle_event("toggle", _params, socket) do
    socket =
      socket
      |> update(:expanded, &(!&1))

    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    socket =
      socket
      |> assign_agent()
      |> assign(messages: [], new_message: nil, in_progress: false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_content}, socket) do
    message = AI.Message.user(message_content)

    agent = socket.assigns.agent

    {:ok, _} =
      agent
      |> AI.Agent.run(message)

    socket =
      socket
      |> update(:messages, &(&1 ++ [message]))
      |> assign(in_progress: true, new_message: nil)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, content}, socket) do
    socket =
      socket
      |> update(:new_message, fn
        nil -> content
        message -> message <> content
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_processed, message}, socket) do
    socket =
      socket
      |> update(:messages, &(&1 ++ [message]))
      |> assign(new_message: nil, in_progress: false)

    {:noreply, socket}
  end

  defp assign_agent(socket) do
    pid = self()

    callbacks = %{
      on_llm_new_delta: fn _chain, langchain_message_deltas ->
        merged_content = langchain_message_deltas |> AI.Message.Delta.merged_contents()

        merged_content
        |> Enum.map(fn
          %{type: :text, content: content} ->
            send(pid, {:new_message, content})

          _ ->
            nil
        end)
      end,
      on_message_processed: fn _chain, langchain_message ->
        message = AI.Message.from_langchain(langchain_message)

        send(pid, {:message_processed, message})
      end
    }

    {:ok, agent} =
      AI.Agent.start_link(%{
        model_name: "gpt-4.1-mini",
        function_context: %{actor: socket.assigns.actor},
        callbacks: callbacks,
        stream: true
      })

    socket
    |> assign(:agent, agent)
  end

  defp disabled(in_progress) do
    in_progress
  end

  ## Components

  attr :message, AI.Message, required: true

  defp message(%{message: %{role: :user}} = assigns) do
    ~H"""
    <div id={@message.id} class="relative flex w-full flex-col items-end">
      <div class="max-w-[70%] prose rounded-xl bg-gray-200 px-4 py-2">
        <.content :for={content <- @message.contents} content={content} />
      </div>
    </div>
    """
  end

  defp message(%{message: %{role: :assistant}} = assigns) do
    ~H"""
    <div id={@message.id} class="prose">
      <.content :for={content <- @message.contents} content={content} />
    </div>
    """
  end

  defp message(assigns) do
    ~H"""
    """
  end

  attr :content, AI.Message.ContentPart, required: true

  defp content(%{content: %{type: :text}} = assigns) do
    ~H"""
    <p>{@content.content |> U.Md.html() |> raw()}</p>
    """
  end

  defp content(assigns) do
    ~H"""
    """
  end
end

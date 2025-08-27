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
      |> assign(
        messages: [],
        new_message: nil,
        queued_contents: []
      )
      |> assign(
        in_progress: false,
        uploading: false,
        expanded: false
      )
      |> allow_upload(:files,
        accept: ["image/*", "application/pdf"],
        max_entries: 5,
        external: &presign_upload/2,
        auto_upload: true,
        progress: &handle_progress/3
      )

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
      phx-drop-target={@uploads.files.ref}
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
        <form phx-change="validate" phx-submit="send_message" class="flex flex-col gap-y-2">
          <.live_file_input class="hidden" upload={@uploads.files} />
          <div class="flex flex-wrap gap-2">
            <div :for={entry <- @uploads.files.entries}>
              <div class="relative text-sm">
                <.file_card
                  filename={entry.client_name}
                  mime_type={entry.client_type}
                  progress={entry.progress}
                />
              </div>
            </div>
          </div>
          <div>
            <textarea
              id="chatbot-input"
              name="message"
              class="w-full rounded-lg border-1 p-2"
              phx-hook="SubmitOnMetaEnter"
            />
            <button
              type="submit"
              class="w-24 cursor-pointer rounded bg-blue-500 px-4 py-2 font-bold text-white hover:bg-blue-700 disabled:bg-gray-300"
              disabled={disabled(@in_progress, @uploading)}
            >
              {if !disabled(@in_progress, @uploading), do: "Send", else: "..."}
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
  def handle_event("validate", _params, socket) do
    socket =
      socket
      |> assign_uploading()

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_content}, socket) do
    # just consume
    consume_uploaded_entries(socket, :files, fn _, _ -> {:ok, nil} end)

    message =
      AI.Message.user(
        socket.assigns.queued_contents ++ [%{type: :text, content: message_content}]
      )

    {:ok, _} =
      socket.assigns.agent
      |> AI.Agent.run(message)

    socket =
      socket
      |> update(:messages, &(&1 ++ [message]))
      |> assign(queued_contents: [], in_progress: true, new_message: nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "file-uploaded",
        %{
          "filename" => filename,
          "file_url" => file_url,
          "mime_type" => mime_type
        },
        socket
      ) do
    socket =
      socket
      |> update(
        :queued_contents,
        &(&1 ++
            [
              %{
                type: :text,
                content: """
                This file can be used when needed.
                - filename: #{filename}
                - file_url: #{file_url}
                - mime_type: #{mime_type}
                """,
                visible: false
              },
              %{
                type: :file,
                content: nil,
                opts: %{filename: filename, mime_type: mime_type},
                virtual: true
              }
            ])
      )
      |> assign_uploading()

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

  @impl true
  def handle_info({:navigate, path}, socket) do
    socket =
      socket
      |> push_navigate(to: path)

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
        pid: pid,
        callbacks: callbacks,
        stream: true
      })

    socket
    |> assign(:agent, agent)
  end

  defp presign_upload(entry, socket) do
    {:ok, %{upload_url: upload_url}} =
      AI.Upload.upload_url(
        :gemini,
        entry.client_name,
        entry.client_size,
        mime_type: entry.client_type,
        origin: AndrewWeb.Endpoint.url()
      )

    {:ok, %{uploader: "Gemini", upload_url: upload_url, uuid: entry.uuid}, socket}
  end

  defp handle_progress(:files, _entry, socket) do
    {:noreply, socket}
  end

  defp assign_uploading(socket) do
    uploading =
      socket.assigns.uploads.files.entries
      |> Enum.map(& &1.progress)
      |> Enum.any?(&(&1 < 100))

    socket
    |> assign(:uploading, uploading)
  end

  defp content_type(mime_type) do
    case mime_type do
      "image/" <> _ -> :image
      "application/pdf" -> :file
    end
  end

  defp file_type(mime_type) do
    case mime_type do
      "image/" <> _ -> "IMG"
      "application/pdf" -> "PDF"
    end
  end

  defp disabled(in_progress, uploading) do
    in_progress || uploading
  end

  ## Components

  attr :message, AI.Message, required: true
  attr :has_visible_content, :boolean

  defp message(%{message: %{role: :user}, has_visible_content: true} = assigns) do
    ~H"""
    <div id={@message.id} class="relative flex w-full flex-col items-end">
      <div class="max-w-[70%] prose rounded-xl bg-gray-200 px-4 py-2">
        <.content :for={content <- @message.contents} content={content} />
      </div>
    </div>
    """
  end

  defp message(%{message: %{role: :assistant}, has_visible_content: true} = assigns) do
    ~H"""
    <div id={@message.id} class="prose">
      <.content :for={content <- @message.contents} content={content} />
    </div>
    """
  end

  defp message(%{has_visible_content: false} = assigns) do
    ~H"""
    """
  end

  defp message(%{message: %{role: role, contents: contents}} = assigns) do
    has_visible_content =
      role in [:user, :assistant] and contents |> Enum.any?(fn content -> content.visible end)

    assigns = assigns |> assign(:has_visible_content, has_visible_content)

    message(assigns)
  end

  attr :content, AI.Message.ContentPart, required: true

  defp content(%{content: %{visible: false}} = assigns) do
    ~H"""
    """
  end

  defp content(%{content: %{type: :text}} = assigns) do
    ~H"""
    <p>{@content.content |> U.Md.html() |> raw()}</p>
    """
  end

  defp content(%{content: %{type: :file}} = assigns) do
    ~H"""
    <div>
      <.file_card filename={@content.opts[:filename]} mime_type={@content.opts[:mime_type]} />
    </div>
    """
  end

  defp content(assigns) do
    ~H"""
    """
  end

  attr :filename, :string, required: true
  attr :mime_type, :string, required: true
  attr :progress, :integer, default: 100

  defp file_card(assigns) do
    ~H"""
    <div class="max-w-60 flex h-20 items-center gap-x-2 rounded-lg bg-gray-700 p-3 text-white">
      <.file_icon content_type={content_type(@mime_type)} progress={@progress} />
      <div class="flex flex-col overflow-hidden">
        <span class="truncate text-sm">{@filename}</span>
        <span class="text-xs">{file_type(@mime_type)}</span>
      </div>
    </div>
    """
  end

  attr :content_type, :string, required: true
  attr :progress, :integer, default: 100

  defp file_icon(assigns) do
    icon =
      case assigns.content_type do
        :image -> "hero-photo"
        :file -> "hero-document-text"
      end

    bg =
      case assigns.content_type do
        :image -> "bg-blue-500"
        :file -> "bg-pink-500"
      end

    assigns =
      assigns
      |> assign(icon: icon, bg: bg)

    ~H"""
    <div class={["rounded-lg p-2", @bg]}>
      <.icon :if={@progress == 100} name={@icon} />
      <.progress_circle :if={@progress} progress={@progress} />
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :progress, :integer, required: true

  defp progress_circle(assigns) do
    ~H"""
    <svg
      :if={@progress < 100}
      class={["h-5 w-5 animate-spin text-white", @class]}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
      </circle>
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end
end

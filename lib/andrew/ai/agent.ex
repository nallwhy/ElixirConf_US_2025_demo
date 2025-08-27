defmodule Andrew.AI.Agent do
  use GenServer
  require Logger
  alias Andrew.AI.LLM
  alias Andrew.AI.Message
  alias Andrew.AI.Tools

  @timeout :timer.seconds(30)

  @default_system_prompt """
  You are Andrew, an intelligent assistant for invoice management.

  ## Your Role
  - Professional assistant specializing in invoicing and billing
  - Communicate clearly and efficiently
  - Guide users to appropriate pages for performing actions

  ## Capabilities

  ### Client Management
  - Help users navigate to client creation/update pages
  - Extract data from files to pre-populate forms
  - Guide users through the client management process

  ### Invoice Operations
  - Guide users to invoice creation/management pages
  - Help extract invoice data from files
  - Provide navigation to relevant invoice pages

  ## Action Strategy
  **IMPORTANT**: Instead of performing create/update actions directly:
  1. **Navigate to appropriate pages** for data entry actions (create, update)
  2. **Extract data from files** when available to help pre-populate forms
  3. **Use query parameters** to pass extracted data to forms
  4. **Only perform read operations** directly (list, search, view)

  ## Guidelines
  1. **Explain before navigating**: Always describe where you're taking the user and why
  2. **Extract data when helpful**: Use file extraction to pre-populate form data
  3. **Use navigation tools** to guide users to the right pages
  4. **Handle errors gracefully** with alternatives
  5. **Navigation happens automatically**: When using navigation tools, the page change occurs automatically - no need to mention URLs or ask users to click anything

  ## Communication Pattern
  For create/update requests:
  1. Explain what you understand from the request
  2. Extract relevant data from files if available
  3. Navigate to the appropriate form page with pre-populated data
  4. Explain what the user can do on that page

  For read/search requests:
  1. Use available tools to gather information
  2. Present the results clearly
  3. Suggest relevant next actions or navigation options

  ## Navigation Strategy
  - **Create actions**: Navigate to creation pages (e.g., /clients/new)
  - **Update actions**: Navigate to edit pages with appropriate parameters
  - **View actions**: Navigate to detail or list pages
  - **Always pass data** via query parameters when possible to help users

  Always prioritize user experience and workflow efficiency.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def run(agent, message, opts \\ []) do
    GenServer.call(agent, {:run, message, opts}, @timeout)
  end

  @impl true
  def init(opts) do
    pid = opts[:pid]
    listener_id = opts[:listener_id]
    function_context = opts[:function_context] || []

    tools =
      [
        Tools.navigate_to_page(pid, listener_id),
        Tools.extract_data_from_file()
        # AshAi.functions(otp_app: :andrew, actor: function_context[:actor])
      ]
      |> List.flatten()

    callbacks =
      case opts[:callbacks] do
        nil ->
          %{
            on_llm_new_delta: fn _chain, message_delta ->
              IO.write(message_delta.content)
            end,
            on_message_processed: fn _chain, _message ->
              IO.write("\n--\n")
            end
          }

        handler ->
          handler
      end

    :ok = Phoenix.PubSub.subscribe(Andrew.PubSub, "client:created")

    llm =
      LLM.new(%{
        model_name: opts[:model_name],
        system_prompt: opts[:system_prompt] || @default_system_prompt,
        tools: tools,
        function_context: function_context,
        callbacks: callbacks,
        stream: opts[:stream] || true
      })

    {:ok, %{llm: llm, pid: pid, listener_id: listener_id}}
  end

  @impl true
  def handle_call({:run, %Message{} = message, opts}, _from, %{llm: llm} = state) do
    new_llm =
      llm
      |> LLM.add_message(message)

    {:reply, {:ok, nil}, %{state | llm: new_llm}, {:continue, {:run, opts}}}
  end

  @impl true
  def handle_continue({:run, _opts}, %{llm: llm, pid: pid} = state) do
    new_llm =
      llm
      |> LLM.run()
      |> case do
        {:ok, new_llm} ->
          new_llm

        {:error, new_llm, error} ->
          Logger.warning("Error running chain: #{inspect(error)}")
          new_llm
      end

    send(pid, :chain_processed)

    {:noreply, %{state | llm: new_llm}}
  end

  @impl true
  def handle_info(
        %Ash.Notifier.Notification{resource: resource, action: action, data: data},
        %{llm: llm, pid: pid, listener_id: listener_id} = state
      ) do
    data_listener_id = data |> Ash.Resource.get_metadata(:listener_id)

    message =
      case {data_listener_id, resource, action} do
        {^listener_id, Andrew.Domain.Invoicing.Client, %{name: :create}} ->
          Message.user([
            %{
              type: :text,
              content: """
              New client is created. Let's do the next step.
              - client_id: #{data.id}
              """,
              visible: false
            }
          ])

        _ ->
          nil
      end

    new_llm =
      case message do
        nil ->
          llm

        message ->
          send(pid, {:message_processed, message})

          llm |> LLM.add_message(message)
      end

    {:noreply, %{state | llm: new_llm}, {:continue, {:run, nil}}}
  end
end

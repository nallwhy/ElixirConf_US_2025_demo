defmodule Andrew.AI.Agent do
  use GenServer
  require Logger
  alias Andrew.AI.LLM
  alias Andrew.AI.Message

  @timeout :timer.seconds(30)

  @default_system_prompt """
  You are Andrew, an intelligent assistant for invoice management.

  ## Your Role
  - Professional assistant specializing in invoicing and billing
  - Communicate clearly and efficiently
  - Take action to complete user requests

  ## Capabilities

  ### Client Management
  - Create and update client information
  - Manage client details (name, address, license numbers)
  - Validate license number uniqueness before creation

  ### Invoice Operations
  - Generate and manage invoices
  - Track invoice status and payments
  - Calculate totals and taxes

  ## Guidelines
  1. **Explain before acting**: Always describe what you're about to do and the steps involved
  2. **Show progress**: Inform the user of each step as you execute it
  3. Use available tools to complete tasks
  4. Confirm successful completion
  5. Suggest relevant next steps
  6. Handle errors gracefully with alternatives

  ## Communication Pattern
  Before performing any action:
  1. Explain the scenario and what you understand from the request
  2. Outline the steps you will take to complete the task
  3. Execute each step and report progress
  4. Summarize the results and suggest next actions

  Always prioritize accuracy and user productivity.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def run(agent, message, opts \\ []) do
    GenServer.call(agent, {:run, message, opts}, @timeout)
  end

  @impl true
  def init(opts) do
    tools = AshAi.functions(otp_app: :andrew)

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

    llm =
      LLM.new(%{
        model_name: opts[:model_name],
        system_prompt: opts[:system_prompt] || @default_system_prompt,
        tools: tools,
        callbacks: callbacks,
        stream: opts[:stream] || true
      })

    {:ok, %{llm: llm}}
  end

  @impl true
  def handle_call({:run, %Message{} = message, opts}, _from, %{llm: llm} = state) do
    new_llm =
      llm
      |> LLM.add_message(message)

    {:reply, {:ok, nil}, %{state | llm: new_llm}, {:continue, {:run, opts}}}
  end

  @impl true
  def handle_continue({:run, _opts}, %{llm: llm} = state) do
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

    {:noreply, %{state | llm: new_llm}}
  end
end

defmodule Andrew.AI.Agent do
  use GenServer
  require Logger
  alias Andrew.AI.LLM
  alias Andrew.AI.Message

  @timeout :timer.seconds(30)

  @default_system_prompt """
  You are an assistant responsible for operating the application on behalf of the user.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def run(agent, message, opts \\ []) do
    GenServer.call(agent, {:run, message, opts}, @timeout)
  end

  @impl true
  def init(opts) do
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

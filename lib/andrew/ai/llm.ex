defmodule Andrew.AI.LLM do
  @type t :: %__MODULE__{
          model_name: String.t(),
          api_key: String.t() | nil,
          system_prompt: String.t() | nil,
          callbacks: map() | nil,
          stream: boolean(),
          chain: any()
        }

  @enforce_keys [:model_name]
  defstruct @enforce_keys ++
              [
                api_key: nil,
                system_prompt: nil,
                callbacks: nil,
                stream: false,
                chain: nil
              ]

  alias Andrew.AI.Message
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  alias Andrew.Utils, as: U

  @spec new(map()) :: t()
  def new(params) do
    struct(__MODULE__, params |> Map.put_new_lazy(:api_key, &default_api_key/0))
    |> put_chain()
  end

  @spec add_message(t(), Message.t()) :: t()
  def add_message(%__MODULE__{chain: chain} = llm, %Message{} = message) do
    new_chain =
      chain
      |> LLMChain.add_message(message |> Message.to_langchain())

    %__MODULE__{llm | chain: new_chain}
  end

  @spec run(t()) :: {:ok, t()} | {:error, t(), any()}
  def run(llm) do
    llm.chain
    |> LLMChain.run(mode: :while_needs_response)
    |> case do
      {:ok, new_chain} ->
        {:ok, %__MODULE__{llm | chain: new_chain}}

      {:error, new_chain, error} ->
        {:error, %__MODULE__{llm | chain: new_chain}, error}
    end
  end

  defp put_chain(
         %__MODULE__{
           model_name: model_name,
           api_key: api_key,
           system_prompt: system_prompt,
           callbacks: callbacks,
           stream: stream
         } = llm
       ) do
    model = ChatOpenAI.new!(%{api_key: api_key, model: model_name, stream: stream})

    chain =
      %{llm: model}
      |> LLMChain.new!()
      |> U.Nillable.run_if(
        system_prompt,
        &(&1 |> LLMChain.add_message(LangChain.Message.new_system!(system_prompt)))
      )
      |> U.Nillable.run_if(
        callbacks,
        &(&1 |> LLMChain.add_callback(callbacks))
      )

    %__MODULE__{llm | chain: chain}
  end

  defp default_api_key() do
    Application.fetch_env!(:andrew, :openai)[:api_key]
  end
end

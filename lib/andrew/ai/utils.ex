defmodule Andrew.AI.Utils do
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias LangChain.Message
  alias LangChain.Message.ContentPart

  def extract_data_from_file(file_url, mime_type, json_schema, opts \\ []) do
    model_name = opts |> Keyword.get(:model_name, "gemini-2.5-flash-lite")

    llm_model =
      ChatGoogleAI.new!(%{
        api_key: gemini_api_key(),
        model: model_name,
        json_response: true,
        json_schema: json_schema,
        stream: false
      })

    messages =
      [
        Message.new_system!("""
        Extracts data in JSON format from a file.
        If a value cannot be found, simply exclude it from the result, instead of returning placeholder values such as "unknown", "none".
        """),
        Message.new_user!([
          ContentPart.new!(%{
            type: :file_url,
            content: file_url,
            options: [media: mime_type]
          })
        ])
      ]

    LLMChain.new!(%{llm: llm_model})
    |> LLMChain.add_messages(messages)
    |> LLMChain.run()
    |> case do
      {:ok, chain} ->
        [%{content: json} | _] = chain.last_message.content

        {:ok,
         json |> String.trim_leading("```json") |> String.trim_trailing("```") |> Jason.decode!()}

      {:error, _chain, error} ->
        {:error, error}
    end
  end

  defp gemini_api_key() do
    Application.fetch_env!(:andrew, :gemini)[:api_key]
  end
end

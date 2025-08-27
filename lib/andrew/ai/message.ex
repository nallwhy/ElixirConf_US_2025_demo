defmodule Andrew.AI.Message do
  alias Andrew.Utils, as: U

  defmodule Delta do
    def merged_contents(langchain_message_deltas) do
      merged = langchain_message_deltas |> LangChain.MessageDelta.merge_deltas()

      get_in(merged.merged_content) || []
    end
  end

  defmodule ContentPart do
    @type t :: %__MODULE__{
            id: String.t(),
            type: :text | :file,
            content: String.t(),
            opts: map(),
            visible: boolean(),
            virtual: boolean()
          }

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :type, Ecto.Enum, values: [:text, :file]
      field :content, :string
      field :opts, :map, default: %{}
      field :visible, :boolean, default: true
      field :virtual, :boolean, default: false
    end

    def new(attrs) do
      changeset(attrs)
      |> apply_action!(:insert)
    end

    def changeset(struct \\ %__MODULE__{}, attrs) do
      struct
      |> cast(attrs, [:id, :type, :content, :opts, :visible, :virtual])
      |> Andrew.AI.Message.put_new_id()
      |> normalize_opts()
    end

    def text_attr(attrs) do
      %{type: :text, content: attrs}
    end

    def from_langchain(%LangChain.Message.ContentPart{} = content_part) do
      new(%{
        type: content_part.type,
        content: content_part.content,
        opts: content_part.options |> Map.new()
      })
    end

    def to_langchain(%__MODULE__{
          type: type,
          content: content,
          opts: opts
        }) do
      LangChain.Message.ContentPart.new!(%{
        type: type,
        content: content,
        options:
          opts
          |> Keyword.new()
      })
    end

    defp normalize_opts(%Ecto.Changeset{changes: changes} = changeset) do
      opts =
        changes
        |> Map.get(:opts, %{})
        |> Enum.map(fn {key, value} ->
          atom_key =
            cond do
              is_binary(key) -> key |> String.to_existing_atom()
              is_atom(key) -> key
            end

          {atom_key, value}
        end)
        |> Map.new()

      %{changeset | changes: Map.put(changes, :opts, opts)}
    end
  end

  defmodule ToolCall do
    @type t :: %__MODULE__{
            id: String.t(),
            tool_name: String.t(),
            arguments: map()
          }

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :tool_name, :string
      field :arguments, :map
    end

    def new(attrs) do
      changeset(attrs)
      |> apply_action!(:insert)
    end

    def changeset(struct \\ %__MODULE__{}, attrs) do
      struct
      |> cast(attrs, [:id, :tool_name, :arguments])
    end

    def from_langchain(%LangChain.Message.ToolCall{} = tool_call) do
      %{
        id: tool_call.call_id,
        tool_name: tool_call.name,
        arguments: tool_call.arguments
      }
    end

    def to_langchain(%__MODULE__{id: id, tool_name: tool_name, arguments: arguments}) do
      LangChain.Message.ToolCall.new!(%{
        call_id: id,
        name: tool_name,
        arguments: arguments
      })
    end
  end

  defmodule ToolResult do
    @type t :: %__MODULE__{
            tool_call_id: String.t(),
            tool_name: String.t(),
            processed_content: map(),
            contents: list(ContentPart.t())
          }

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :tool_call_id, :string
      field :tool_name, :string
      field :processed_content, Andrew.Types.Any.EctoType

      embeds_many :contents, ContentPart, on_replace: :delete
    end

    def new(attrs) do
      changeset(attrs)
      |> apply_action!(:insert)
    end

    def changeset(struct \\ %__MODULE__{}, attrs) do
      struct
      |> cast(attrs, [:tool_call_id, :tool_name, :processed_content])
      |> cast_embed(:contents, with: &ContentPart.changeset/2)
    end

    def from_langchain(%LangChain.Message.ToolResult{} = tool_result) do
      %{
        tool_call_id: tool_result.tool_call_id,
        tool_name: tool_result.name,
        processed_content: tool_result.processed_content,
        contents: tool_result.content
      }
    end

    def to_langchain(%__MODULE__{
          tool_call_id: tool_call_id,
          tool_name: tool_name,
          processed_content: processed_content,
          contents: contents
        }) do
      LangChain.Message.ToolResult.new!(%{
        tool_call_id: tool_call_id,
        name: tool_name,
        processed_content: processed_content,
        content: contents
      })
    end
  end

  @type t :: %__MODULE__{
          id: String.t(),
          role: :user | :assistant | :system | :tool,
          contents: list(ContentPart.t()),
          tool_calls: list(ToolCall.t()),
          tool_results: list(ToolResult.t())
        }

  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :id, :string
    field :role, Ecto.Enum, values: [:user, :assistant, :system, :tool]

    embeds_many :contents, ContentPart, on_replace: :delete
    embeds_many :tool_calls, ToolCall, on_replace: :delete
    embeds_many :tool_results, ToolResult, on_replace: :delete
  end

  def new(attrs) do
    changeset(attrs)
    |> apply_action!(:insert)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:id, :role])
    |> put_new_id()
    |> cast_embed(:contents, with: &ContentPart.changeset/2)
    |> cast_embed(:tool_calls, with: &ToolCall.changeset/2)
    |> cast_embed(:tool_results, with: &ToolResult.changeset/2)
  end

  def user(contents) when is_list(contents) do
    new(%{role: :user, contents: contents})
  end

  def user(content) when is_binary(content) do
    new(%{role: :user, contents: [ContentPart.text_attr(content)]})
  end

  def assistant(contents) when is_list(contents) do
    new(%{role: :assistant, contents: contents})
  end

  def assistant(content) when is_binary(content) do
    new(%{role: :assistant, contents: [ContentPart.text_attr(content)]})
  end

  def tool(contents) when is_list(contents) do
    new(%{role: :tool, contents: contents})
  end

  def has_tool_calls?(%__MODULE__{tool_calls: tool_calls}) do
    tool_calls |> Enum.any?()
  end

  def has_tool_results?(%__MODULE__{tool_results: tool_results}) do
    tool_results |> Enum.any?()
  end

  def from_langchain(%LangChain.Message{} = langchain_message) do
    contents =
      case langchain_message.content do
        content when is_binary(content) ->
          [%{type: :text, content: content}]

        content when is_list(content) ->
          content
          |> Enum.map(&(&1 |> ContentPart.from_langchain() |> U.Map.deep_from_struct()))

        nil ->
          []
      end

    tool_calls =
      case langchain_message.tool_calls do
        [_ | _] = langchain_tool_calls ->
          langchain_tool_calls
          |> Enum.map(&(&1 |> ToolCall.from_langchain() |> U.Map.deep_from_struct()))

        _ ->
          []
      end

    tool_results =
      case langchain_message.tool_results do
        [_ | _] = langchain_tool_results ->
          langchain_tool_results
          |> Enum.map(&(&1 |> ToolResult.from_langchain() |> U.Map.deep_from_struct()))

        _ ->
          []
      end

    new(%{
      role: langchain_message.role,
      contents: contents,
      tool_calls: tool_calls,
      tool_results: tool_results
    })
  end

  def to_langchain(%__MODULE__{
        role: role,
        contents: contents,
        tool_calls: tool_calls,
        tool_results: tool_results
      }) do
    langchain_contents =
      contents
      |> Enum.reject(& &1.virtual)
      |> Enum.map(&ContentPart.to_langchain/1)

    langchain_tool_calls =
      tool_calls
      |> Enum.map(&ToolCall.to_langchain/1)

    langchain_tool_results =
      tool_results
      |> Enum.map(&ToolResult.to_langchain/1)
      |> case do
        [] -> nil
        langchain_tool_results -> langchain_tool_results
      end

    LangChain.Message.new!(%{
      role: role,
      content: langchain_contents,
      tool_calls: langchain_tool_calls,
      tool_results: langchain_tool_results
    })
  end

  def put_new_id(%Ecto.Changeset{changes: changes} = changeset) do
    %{changeset | changes: changes |> Map.put_new(:id, Ash.UUIDv7.generate())}
  end
end

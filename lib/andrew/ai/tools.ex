defmodule Andrew.AI.Tools do
  alias LangChain.Function

  def navigate_to_page(pid) do
    Function.new!(%{
      name: "navigate_to_page",
      description: """
      Navigate user to a specific page in the application.

      Pages
      - list_clients
      """,
      parameters_schema: %{
        "type" => "object",
        "properties" => %{
          "page_name" => %{
            "type" => "string",
            "enum" => [
              "list_clients"
            ]
          }
        },
        "additionalProperties" => false,
        "required" => ["page_name"]
      },
      strict: true,
      async: false,
      function: fn %{"page_name" => page_name}, _context ->
        path =
          case page_name do
            "list_clients" -> "/clients"
            _ -> nil
          end

        send(pid, {:navigate, path})

        {:ok, path}
      end
    })
  end
end

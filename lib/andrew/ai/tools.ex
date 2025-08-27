defmodule Andrew.AI.Tools do
  alias LangChain.Function
  alias Andrew.AI.Utils

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

  def extract_data_from_file() do
    parameters_schema =
      %{
        "type" => "object",
        "properties" => %{
          "file_url" => %{
            "type" => "string",
            "description" => "URL of the file to extract data from."
          },
          "mime_type" => %{"type" => "string", "description" => "MIME type of the file."},
          "job" => %{
            "type" => "string",
            "enum" => ["create_client"],
            "description" => "Job type for data extraction."
          }
        }
      }

    Function.new!(%{
      name: "file_data_extractor",
      description: """
      Extracts data in JSON format from a file.
      If a value cannot be found, simply exclude it from the result, instead of returning placeholder values such as "unknown", "none".
      """,
      parameters_schema: parameters_schema,
      strict: true,
      async: true,
      function: fn %{"file_url" => file_url, "mime_type" => mime_type, "job" => job_str},
                   _context ->
        job = job_str |> String.to_existing_atom()

        json_schema = to_schema(job)

        Utils.extract_data_from_file(file_url, mime_type, json_schema)
        |> case do
          {:ok, json} -> {:ok, json |> Jason.encode!(), json}
          {:error, error} -> {:error, error}
        end
      end
    })
  end

  defp to_schema(:create_client) do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "license_no" => %{"type" => "string"},
        "address" => %{"type" => "string"}
      }
    }
  end
end

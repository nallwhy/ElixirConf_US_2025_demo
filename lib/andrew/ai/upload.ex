defmodule Andrew.AI.Upload do
  @gemini_base_url "https://generativelanguage.googleapis.com"

  def upload_url(:gemini, filename, byte_size, opts \\ []) do
    mime_type = opts |> Keyword.get(:mime_type, MIME.from_path(filename))
    origin = opts |> Keyword.get(:origin)

    headers = [
      {"X-Goog-Upload-Protocol", "resumable"},
      {"X-Goog-Upload-Command", "start"},
      {"X-Goog-Upload-Header-Content-Length", byte_size},
      {"X-Goog-Upload-Header-Content-Type", mime_type},
      {"Content-Type", "application/json"},
      {"Origin", origin}
    ]

    body = %{"file" => %{"display_name" => filename}}

    Req.post(
      "#{@gemini_base_url}/upload/v1beta/files?key=#{gemini_api_key()}",
      headers: headers,
      json: body
      # connect_options: Ext.proxy_connect_options()
    )
    |> case do
      {:ok, %{status: 200, headers: headers}} ->
        [upload_url | _] = headers["x-goog-upload-url"]

        {:ok, %{upload_url: upload_url}}

      {:error, error} ->
        {:error, error}
    end
  end

  def upload(:gemini, upload_url, file) do
    byte_size = file |> byte_size()

    headers = [
      {"Content-Length", byte_size},
      {"X-Goog-Upload-Offset", "0"},
      {"X-Goog-Upload-Command", "upload, finalize"}
    ]

    {:ok, %{body: body}} =
      Req.post(upload_url,
        headers: headers,
        body: file
        # connect_options: Ext.proxy_connect_options()
      )

    %{"file" => %{"uri" => file_url}} = body

    {:ok, %{url: file_url}}
  end

  defp gemini_api_key() do
    Application.fetch_env!(:andrew, :gemini)[:api_key] |> IO.inspect()
  end
end

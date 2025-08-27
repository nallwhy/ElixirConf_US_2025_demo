defmodule Andrew.Utils.URI do
  alias Andrew.Utils, as: U

  def append_query(uri_str, params) do
    %URI{query: query_str} = uri = uri_str |> URI.parse()
    query = Plug.Conn.Query.decode(query_str || "")
    new_query = query |> U.Map.deep_merge(params)

    new_query_str = new_query |> Plug.Conn.Query.encode()

    %URI{uri | query: new_query_str} |> URI.to_string()
  end
end

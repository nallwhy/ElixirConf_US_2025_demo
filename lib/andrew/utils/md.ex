defmodule Andrew.Utils.Md do
  def html(markdown, opts \\ []) do
    extensions =
      opts
      |> Keyword.get(:extensions,
        strikethrough: true,
        table: true,
        tasklist: true
      )

    markdown
    |> MDEx.parse_document!(extension: extensions)
    |> MDEx.to_html!(render: [unsafe: true])
  end
end

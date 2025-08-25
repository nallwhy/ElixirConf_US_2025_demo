defmodule Andrew.Domain.Invoicing do
  use Ash.Domain, extensions: [AshAi]

  resources do
    resource __MODULE__.Client
  end

  tools do
    tool :create_client, __MODULE__.Client, :create
  end
end

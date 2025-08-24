defmodule Andrew.Domain.Invoicing do
  use Ash.Domain

  resources do
    resource __MODULE__.Client
  end
end

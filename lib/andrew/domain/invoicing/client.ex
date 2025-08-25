defmodule Andrew.Domain.Invoicing.Client do
  use Ash.Resource,
    domain: Andrew.Domain.Invoicing,
    data_layer: AshSqlite.DataLayer

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :license_no, :string, allow_nil?: false, public?: true
    attribute :address, :string, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :license_no, :address]
    end

    update :update do
      primary? true
      accept [:name, :address]
    end
  end

  identities do
    identity :unique_license_no, [:license_no]
  end

  sqlite do
    table "clients"
    repo Andrew.Repo
  end
end

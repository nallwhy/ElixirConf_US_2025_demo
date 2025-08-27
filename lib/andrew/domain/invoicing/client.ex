defmodule Andrew.Domain.Invoicing.Client do
  use Ash.Resource,
    domain: Andrew.Domain.Invoicing,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :license_no, :string, allow_nil?: false, public?: true
    attribute :address, :string, allow_nil?: false
    attribute :phone_number, :string, allow_nil?: true
    attribute :email, :string, allow_nil?: true
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(default_sort: [id: :desc])
    end

    create :create do
      primary? true
      accept [:name, :license_no, :address, :phone_number, :email]
      argument :listener_id, :string, public?: false
      metadata :listener_id, :string

      change after_action(fn cs, client, _ctx ->
               listener_id = cs |> Ash.Changeset.get_argument(:listener_id)
               client = client |> Ash.Resource.put_metadata(:listener_id, listener_id)

               {:ok, client}
             end)
    end

    update :update do
      primary? true
      accept [:name, :address, :phone_number, :email]
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy always() do
      authorize_if always()
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Andrew.PubSub
    prefix "client"

    publish :create, "created"
  end

  identities do
    identity :unique_license_no, [:license_no]
  end

  sqlite do
    table "clients"
    repo Andrew.Repo
  end
end

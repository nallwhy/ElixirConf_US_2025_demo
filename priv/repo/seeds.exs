# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Andrew.Repo.insert!(%Andrew.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Andrew.Domain.Invoicing.Client

# Create sample clients
sample_clients = [
  %{
    name: "ABC Construction Co.",
    license_no: "CONST-2024-001",
    address: "123 Main Street, New York, NY 10001"
  },
  %{
    name: "XYZ Engineering Ltd.",
    license_no: "ENG-2024-002", 
    address: "456 Technology Blvd, San Francisco, CA 94107"
  },
  %{
    name: "Global Trading Inc.",
    license_no: "TRADE-2024-003",
    address: "789 Commerce Ave, Chicago, IL 60601"
  },
  %{
    name: "Tech Solutions Corp.",
    license_no: "TECH-2024-004",
    address: "321 Innovation Drive, Austin, TX 78701"
  },
  %{
    name: "Green Energy Systems",
    license_no: "ENERGY-2024-005",
    address: "654 Renewable Way, Seattle, WA 98101"
  }
]

Enum.each(sample_clients, fn client_attrs ->
  case Client
       |> Ash.Changeset.for_create(:create, client_attrs)
       |> Ash.create() do
    {:ok, client} ->
      IO.puts("Created client: #{client.name}")
    {:error, error} ->
      IO.puts("Failed to create client #{client_attrs.name}: #{inspect(error)}")
  end
end)

IO.puts("Seeding completed!")

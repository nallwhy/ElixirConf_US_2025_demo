defmodule Andrew.Types.Any do
  use Ash.Type

  @impl Ash.Type
  def storage_type(_), do: :jsonb

  @impl Ash.Type
  def cast_input(value, _), do: {:ok, value}

  @impl Ash.Type
  def cast_stored(value, _), do: {:ok, value}

  @impl Ash.Type
  def dump_to_native(value, _), do: {:ok, value}
end

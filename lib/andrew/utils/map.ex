defmodule Andrew.Utils.Map do
  def deep_from_struct(map) when is_non_struct_map(map) do
    map
    |> Map.new(fn {key, value} ->
      {key, deep_from_struct(value)}
    end)
  end

  def deep_from_struct(map) when is_struct(map) do
    map
    |> Map.from_struct()
    |> deep_from_struct()
  end

  def deep_from_struct(value) when is_list(value) do
    value
    |> Enum.map(&deep_from_struct/1)
  end

  def deep_from_struct(value), do: value

  def deep_merge(%{} = map1, %{} = map2)
      when is_non_struct_map(map1) and is_non_struct_map(map2) do
    map2
    |> Enum.reduce(map1, fn {key, value2}, acc ->
      value1 = Map.get(acc, key)

      if is_non_struct_map(value1) and is_non_struct_map(value2) do
        Map.put(acc, key, deep_merge(value1, value2))
      else
        Map.put(acc, key, value2)
      end
    end)
  end
end

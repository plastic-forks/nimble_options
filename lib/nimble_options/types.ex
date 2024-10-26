defmodule NimbleOptions.Types do
  @moduledoc false

  @basic_types [
    :any,
    :integer,
    :non_neg_integer,
    :pos_integer,
    :float,
    :string,
    :atom,
    nil,
    :boolean,
    :timeout,
    :pid,
    :reference,
    :mfa,
    :mod_arg,
    :keyword_list,
    :non_empty_keyword_list,
    :map
  ]

  defp available_types() do
    types =
      Enum.map(@basic_types, &inspect/1) ++
        [
          "{:keyword_list, keys}",
          "{:non_empty_keyword_list, keys}",
          "{:map, keys}",
          "{:map, key_type, value_type}",
          "{:list, subtype}",
          "{:tuple, subtypes}",
          "{:fun, arity}",
          "{:struct, struct_name}",
          "{:custom, mod, fun, args}",
          "{:in, choices}",
          "{:or, subtypes}"
        ]

    Enum.join(types, ", ")
  end

  @doc false
  def validate_type(value) when value in @basic_types do
    {:ok, value}
  end

  def validate_type({name, keys})
      when name in [:keyword_list, :non_empty_keyword_list, :map] and is_list(keys) do
    validated_keys =
      Enum.map(keys, fn {key, schema} ->
        case validate_type(schema[:type]) do
          {:ok, _} ->
            {key, schema}

          {:error, reason} ->
            throw({:error, "invalid keys given to {#{inspect(name)}, keys} type: #{reason}"})
        end
      end)

    {:ok, {name, validated_keys}}
  catch
    {:error, reason} ->
      {:error, reason}
  end

  def validate_type({:map, key_type, value_type}) do
    valid_key_type =
      case validate_type(key_type) do
        {:ok, validated_key_type} -> validated_key_type
        {:error, reason} -> throw({:error, "invalid key_type for :map type: #{reason}"})
      end

    valid_values_type =
      case validate_type(value_type) do
        {:ok, validated_values_type} -> validated_values_type
        {:error, reason} -> throw({:error, "invalid value_type for :map type: #{reason}"})
      end

    {:ok, {:map, valid_key_type, valid_values_type}}
  catch
    {:error, reason} -> {:error, reason}
  end

  def validate_type({:list, subtype}) do
    case validate_type(subtype) do
      {:ok, validated_subtype} -> {:ok, {:list, validated_subtype}}
      {:error, reason} -> {:error, "invalid subtype given to :list type: #{reason}"}
    end
  end

  def validate_type({:tuple, subtypes}) when is_list(subtypes) do
    validated_subtypes =
      Enum.map(subtypes, fn subtype ->
        case validate_type(subtype) do
          {:ok, validated_subtype} -> validated_subtype
          {:error, reason} -> throw({:error, "invalid subtype given to :tuple type: #{reason}"})
        end
      end)

    {:ok, {:tuple, validated_subtypes}}
  catch
    {:error, reason} -> {:error, reason}
  end

  def validate_type({:fun, arity} = value) when is_integer(arity) and arity >= 0 do
    {:ok, value}
  end

  def validate_type({:struct, struct_name}) when is_atom(struct_name) do
    {:ok, {:struct, struct_name}}
  end

  def validate_type({:struct, struct_name}) do
    {:error, "invalid struct_name for :struct, expected atom, got #{inspect(struct_name)}"}
  end

  def validate_type({:custom, mod, fun, args} = value)
      when is_atom(mod) and is_atom(fun) and is_list(args) do
    {:ok, value}
  end

  # "choices" here can be any enumerable so there's no easy and fast way to validate it.
  def validate_type({:in, _choices} = value) do
    {:ok, value}
  end

  def validate_type({:or, subtypes} = value) when is_list(subtypes) do
    Enum.reduce_while(subtypes, {:ok, value}, fn subtype, acc ->
      case validate_type(subtype) do
        {:ok, _value} -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, "invalid type given to :or type: #{reason}"}}
      end
    end)
  end

  def validate_type(value) do
    {:error, "unknown type #{inspect(value)}.\n\nAvailable types: #{available_types()}"}
  end
end

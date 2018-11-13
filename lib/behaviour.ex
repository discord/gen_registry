defmodule GenRegistry.Behaviour do
  @moduledoc """
  GenRegistry.Behaviour defines the interface that a GenRegistry module should implement.

  It is included to aid the development of replacement GenRegistry like implementations for
  special use cases or for testing.
  """

  alias :ets, as: ETS
  alias GenRegistry.Types

  @callback lookup(ETS.tid(), Types.id()) :: {:ok, pid} | {:error, :not_found}
  @callback lookup_or_start(pid, Types.id(), args :: [term], timeout :: integer) ::
              {:ok, pid} | {:error, term}
  @callback stop(pid, Types.id()) :: :ok | {:error, :not_found}
  @callback count(ETS.tid()) :: integer
  @callback reduce(ETS.tid(), term, ({Types.id(), pid}, term -> term)) :: term
end

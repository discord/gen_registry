defmodule GenRegistry.Behaviour do
  @moduledoc """
  GenRegistry.Behaviour defines the interface that a GenRegistry module should implement.

  It is included to aid the development of replacement GenRegistry like implementations for
  special use cases or for testing.
  """

  alias :ets, as: ETS
  alias GenRegistry.Types

  @callback count(ETS.tab()) :: integer()
  @callback lookup(ETS.tab(), Types.id()) :: {:ok, pid()} | {:error, :not_found}
  @callback lookup_or_start(GenServer.server(), Types.id(), args :: [any()], timeout :: integer()) ::
              {:ok, pid()} | {:error, any()}
  @callback reduce(ETS.tab(), any(), ({Types.id(), pid()}, any() -> any())) :: any()
  @callback sample(ETS.tab()) :: {Types.id(), pid()} | nil
  @callback start(GenServer.server(), Types.id(), args :: [any()], timeout :: integer()) :: {:ok, pid()} | {:error, {:already_started, pid()}} | {:error, any()}
  @callback stop(GenServer.server(), Types.id()) :: :ok | {:error, :not_found}
  @callback to_list(ETS.tab()) :: [{Types.id(), pid()}]
end

defmodule GenRegistry do
  @moduledoc """
  GenRegistry provides a `Registry` like interface for managing processes.
  """

  @behaviour GenRegistry.Behaviour

  use GenServer

  alias :ets, as: ETS
  alias GenRegistry.Types

  defstruct [:worker_module, :worker_type, :workers]

  @typedoc """
  GenRegistry State.

  - worker_module: Module to spawn
  - worker_type: `:supervisor` if the worker_module is a supervisor, `:worker` otherwise
  - workers: ETS table id holding the worker tracking records.
  """
  @type t :: %__MODULE__{
          worker_module: module,
          worker_type: :supervisor | :worker,
          workers: ETS.tab()
        }

  @gen_module Application.get_env(:gen_registry, :gen_module, GenServer)

  ## Client

  @doc """
  Callback called by `Supervisor.init/2`

  It is required that you provide a `:worker_module` argument or the call will fail.
  """
  @spec child_spec(opts :: Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    worker_module = Keyword.fetch!(opts, :worker_module)

    opts =
      opts
      |> Keyword.delete(:worker_module)
      |> Keyword.put_new(:name, worker_module)

    %{
      id: opts[:name],
      start: {__MODULE__, :start_link, [worker_module, opts]},
      type: :supervisor
    }
  end

  @doc """
  Start a registry instance.

  GenRegistry should be run under a supervision tree, it is not recommended to call this directly.
  """
  @spec start_link(module, Keyword.t()) :: {:ok, pid} | {:error, any}
  def start_link(module, opts \\ []) do
    GenServer.start_link(__MODULE__, {module, opts[:name]}, opts)
  end

  @doc """
  Lookup a running a process.

  This is a fast path to the ETS table.
  """
  @spec lookup(table :: ETS.tab(), id :: Types.id()) :: {:ok, pid} | {:error, :not_found}
  def lookup(table, id) do
    case ETS.lookup(table, id) do
      [{^id, pid}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Attempts to lookup a running process by id.

  If the id is not associated with a running process then it is spawned, the optional third
  argument will be passed to `start_link` of the `worker_module` to spawn a new process.
  """
  @spec lookup_or_start(registry :: GenServer.server(), id :: Types.id(), args :: [any], timeout :: integer) ::
          {:ok, pid} | {:error, any}
  def lookup_or_start(registry, id, args \\ [], timeout \\ 5_000)

  def lookup_or_start(registry, id, args, timeout) when is_atom(registry) do
    case lookup(registry, id) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        @gen_module.call(registry, {:lookup_or_start, id, args}, timeout)
    end
  end

  def lookup_or_start(registry, id, args, timeout) do
    @gen_module.call(registry, {:lookup_or_start, id, args}, timeout)
  end

  @doc """
  Safely stops a process managed by the GenRegistry

  In addition to stopping the process, the id is also removed from the GenRegistry

  If the id provided is not registered this will return `{:error, :not_found}`
  """
  @spec stop(registry :: GenServer.server(), id :: Types.id()) :: :ok | {:error, :not_found}
  def stop(registry, id) do
    @gen_module.call(registry, {:stop, id})
  end

  @doc """
  Return the number of running processes in this registry.
  """
  @spec count(table :: ETS.tab()) :: non_neg_integer()
  def count(table) do
    ETS.info(table, :size)
  end

  @doc """
  Return a sample entry from the registry.

  If the registry is empty returns `nil`.
  """
  @spec sample(table :: ETS.tab()) :: {Types.id(), pid()} | nil
  def sample(table) do
    case ETS.first(table) do
      :"$end_of_table" ->
        nil

      key ->
        case ETS.lookup(table, key) do
          [entry] ->
            entry

          _ ->
            sample(table)
        end
    end
  end

  @doc """
  Loop over all the processes and return result.

  The function will be called with two arguments, a two-tuple of `{id, pid}` and then accumulator,
  the function should return the accumulator.

  There is no ordering guarantee when reducing.
  """
  @spec reduce(table :: ETS.tab(), acc :: any, ({Types.id(), pid()}, any() -> any())) :: any
  def reduce(table, acc, func) do
    ETS.foldr(func, acc, table)
  end

  @doc """
  Returns all the entries of the GenRegistry as a list.

  There is no ordering guarantee for the list.
  """
  @spec to_list(table :: ETS.tab()) :: [{Types.id(), pid()}]
  def to_list(table) do
    ETS.tab2list(table)
  end

  ## Server Callbacks

  def init({worker_module, name}) do
    Process.flag(:trap_exit, true)

    worker_type =
      case worker_module.module_info[:attributes][:behaviour] do
        [:supervisor] -> :supervisor
        _ -> :worker
      end

    state = %__MODULE__{
      workers:
        ETS.new(name, [
          :public,
          :set,
          :named_table,
          {:read_concurrency, true}
        ]),
      worker_module: worker_module,
      worker_type: worker_type
    }

    {:ok, state}
  end

  def terminate(_reason, _state) do
    for pid <- Process.get_keys(), is_pid(pid) do
      Process.unlink(pid)
      Process.exit(pid, :kill)
    end

    :ok
  end

  def handle_call({:lookup_or_start, id, args}, _from, state) do
    {:reply, do_lookup_or_start(state, id, args), state}
  end

  def handle_call({:stop, id}, _from, state) do
    {:reply, do_stop(state, id), state}
  end

  # Call from supervisor module.
  def handle_call(
        :which_children,
        _from,
        %__MODULE__{worker_type: worker_type, worker_module: worker_module} = state
      ) do
    children =
      for pid <- Process.get_keys(), is_pid(pid) do
        {:undefined, pid, worker_type, [worker_module]}
      end

    {:reply, children, state}
  end

  def handle_call(
        :count_children,
        _from,
        %__MODULE__{worker_type: worker_type, worker_module: worker_module} = state
      ) do
    counts = [
      specs: 1,
      active: count(worker_module),
      supervisors: 0,
      workers: 0
    ]

    counts =
      case worker_type do
        :worker -> Keyword.put(counts, :workers, counts[:active])
        :supervisor -> Keyword.put(counts, :supervisors, counts[:active])
      end

    {:reply, counts, state}
  end

  def handle_call(_message, _from, state) do
    {:reply, {:error, __MODULE__}, state}
  end

  def handle_info({:EXIT, pid, _reason}, %__MODULE__{workers: workers} = state) do
    ETS.delete(workers, Process.delete(pid))
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  ## Private

  @spec do_lookup_or_start(state :: t, id :: Types.id(), args :: [any]) ::
          {:ok, pid} | {:error, any}
  defp do_lookup_or_start(%__MODULE__{worker_module: worker_module, workers: workers}, id, args) do
    case lookup(workers, id) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        case apply(worker_module, :start_link, args) do
          {:ok, pid} ->
            ETS.insert_new(workers, {id, pid})
            Process.put(pid, id)
            {:ok, pid}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @spec do_stop(state :: t, id :: Types.id()) :: :ok | {:error, :not_found}
  defp do_stop(%__MODULE__{workers: workers}, id) do
    with {:ok, pid} <- lookup(workers, id) do
      Process.unlink(pid)
      Process.exit(pid, :shutdown)
      ETS.delete(workers, Process.delete(pid))
      :ok
    end
  end
end

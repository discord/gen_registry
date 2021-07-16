defmodule ExampleWorker do
  use GenServer

  def start_link(value \\ nil) do
    GenServer.start_link(__MODULE__, value, [])
  end

  def get(pid) do
    GenServer.call(pid, :get)
  end

  def init(value) do
    case value do
      :invalid ->
        {:stop, :invalid}

      value ->
        {:ok, value}
    end
  end

  def handle_call(:get, _from, value) do
    {:reply, value, value}
  end
end

defmodule ExampleSupervisor do
  use Supervisor

  def start_link(module \\ ExampleWorker, opts \\ []) do
    Supervisor.start_link(__MODULE__, {module, opts})
  end

  def init({module, opts}) do
    supervise(
      [
        GenRegistry.Spec.child_spec(module, opts)
      ],
      strategy: :one_for_one
    )
  end
end

defmodule Spy do
  use GenServer

  def start_link(original) do
    GenServer.start_link(__MODULE__, original)
  end

  def replace(pid) when is_pid(pid) do
    start_link(pid)
  end

  def replace(name) do
    case Process.whereis(name) do
      nil ->
        {:error, :not_found}

      pid ->
        true = Process.unregister(name)
        {:ok, spy} = start_link(pid)
        Process.register(spy, name)

        {:ok, spy}
    end
  end

  def calls(pid) do
    GenServer.call(pid, {__MODULE__, :calls})
  end

  def casts(pid) do
    GenServer.call(pid, {__MODULE__, :casts})
  end

  def messages(pid) do
    GenServer.call(pid, {__MODULE__, :messages})
  end

  def init(original) do
    state =
      %{
        original: original,
        calls: [],
        casts: [],
        messages: []
      }

    {:ok, state}
  end

  def handle_call({__MODULE__, key}, _from, state) do
    {:reply, Map.fetch(state, key), state}
  end

  def handle_call(call, _from, state) do
    response = GenServer.call(state.original, call)
    state = Map.update!(state, :calls, &[{call, response} | &1])
    {:reply, response, state}
  end

  def handle_cast(cast, state) do
    GenServer.cast(state.original, cast)
    state = Map.update!(state, :casts, &[cast | &1])
    {:noreply, state}
  end

  def handle_info(info, state) do
    send(state.original, info)
    state = Map.update!(state, :messages, &[info | &1])
    {:noreply, state}
  end
end

ExUnit.start()

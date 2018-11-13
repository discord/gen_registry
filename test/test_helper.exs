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

ExUnit.start()

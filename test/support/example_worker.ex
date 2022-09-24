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

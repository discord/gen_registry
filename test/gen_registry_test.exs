defmodule GenRegistry.Test do
  use ExUnit.Case

  @doc """
  Common setup function that starts a GenRegistry

  In this test context the ExUnit Supervisor will supervise the GenRegistry.  The GenRegistry
  process is registered with the the name of the worker module, this is the default behavior for
  running GenRegistry under supervision so the resulting test code mimics how one would use
  GenRegistry in practice.
  """
  @spec start_registry(ctx :: Map.t()) :: :ok
  def start_registry(_) do
    {:ok, _} = GenRegistry.start_link(ExampleWorker, name: ExampleWorker)
    :ok
  end

  @doc """
  Helper that executes a function until it returns true

  Useful for operations that will eventually complete, instead of sleeping to allow an async
  operation to complete, wait_until will call the function in a loop up to the specified number of
  attempts with the specified delay between attempts.
  """
  @spec wait_until(fun :: (() -> boolean), attempts :: non_neg_integer, delay :: pos_integer) ::
          boolean
  def wait_until(fun, attempts \\ 5, delay \\ 100)

  def wait_until(_, 0, _), do: false

  def wait_until(fun, attempts, delay) do
    case fun.() do
      true ->
        true

      _ ->
        Process.sleep(delay)
        wait_until(fun, attempts - 1, delay)
    end
  end

  describe "lookup/2" do
    setup [:start_registry]

    test "unknown id" do
      assert {:error, :not_found} = GenRegistry.lookup(ExampleWorker, :unknown)
    end

    test "known id" do
      # Start a process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Assert that it can be looked up
      assert {:ok, ^pid} = GenRegistry.lookup(ExampleWorker, :test_id)
    end

    test "mixed ids" do
      # Start a process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Assert that it can be looked up
      assert {:ok, ^pid} = GenRegistry.lookup(ExampleWorker, :test_id)

      # Assert that other ids are still not found
      assert {:error, :not_found} = GenRegistry.lookup(ExampleWorker, :unknown)
    end

    test "removed after the process exits" do
      # Start a new process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Assert that it can be looked up
      assert {:ok, ^pid} = GenRegistry.lookup(ExampleWorker, :test_id)

      # Stop the process
      assert :ok = GenRegistry.stop(ExampleWorker, :test_id)

      # Assert that the previously known id is no longer known
      assert {:error, :not_found} = GenRegistry.lookup(ExampleWorker, :test_id)
    end
  end

  describe "lookup_or_start/4" do
    setup [:start_registry]

    test "unknown id starts a new process" do
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :unknown)
      assert {:ok, ^pid} = GenRegistry.lookup(ExampleWorker, :unknown)
    end

    test "known id returns the running process" do
      # Confirm that the registry is empty
      assert 0 == GenRegistry.count(ExampleWorker)

      # Start a new process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the registry has 1 process
      assert 1 == GenRegistry.count(ExampleWorker)

      # Attempting to start the same id will return the running process
      assert {:ok, ^pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the registry still only has 1 process
      assert 1 == GenRegistry.count(ExampleWorker)
    end

    test "arguments are passed through" do
      # Start a process with a particular value
      assert {:ok, first} = GenRegistry.lookup_or_start(ExampleWorker, :a, [:test_value_a])

      # Start another process with a different value
      assert {:ok, second} = GenRegistry.lookup_or_start(ExampleWorker, :b, [:test_value_b])

      # Assert that the first process has the first value
      assert :test_value_a == ExampleWorker.get(first)

      # Assert that the second process has the second value
      assert :test_value_b == ExampleWorker.get(second)

      # Assert that querying through the returned lookup pid returns the correct value, without
      # having to pass the arguments in again
      assert {:ok, retrieved} = GenRegistry.lookup_or_start(ExampleWorker, :a)
      assert :test_value_a = ExampleWorker.get(retrieved)
    end

    test "invalid arguments return the error and register no process" do
      assert {:error, :invalid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id, [:invalid])
    end

    test "invalid start does not effect running processes (failure isolation)" do
      # Populate the registry with some processes
      for i <- 1..5 do
        assert {:ok, _} = GenRegistry.lookup_or_start(ExampleWorker, i)
      end

      # Confirm that there are 5 processes
      assert 5 == GenRegistry.count(ExampleWorker)

      # Start a process with invalid arguments
      assert {:error, :invalid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id, [:invalid])

      # Confirm that there are still 5 processes in the registry
      assert 5 == GenRegistry.count(ExampleWorker)

      # Confirm that the running processes are unaffected by the failed start
      for i <- 1..5 do
        assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, i)
        assert Process.alive?(pid)
      end
    end

    test "id can be reused if the process exits" do
      # Start a process with a particular value
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id, [:original])

      # Confirm that the process is working correctly
      assert :original == ExampleWorker.get(pid)

      # Confirm that the registry has exactly 1 process
      assert 1 == GenRegistry.count(ExampleWorker)

      # Confirm that an additional lookup_or_start returns the running process
      assert {:ok, ^pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Stop the process
      assert :ok = GenRegistry.stop(ExampleWorker, :test_id)

      # Confirm that the process has stopped
      refute Process.alive?(pid)

      # Confirm that the registry has 0 processes
      assert 0 == GenRegistry.count(ExampleWorker)

      # Attempt to start up a new process with the same id
      assert {:ok, new_pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id, [:updated])

      # Confirm that the process is distinct from the first process
      assert pid != new_pid

      # Confirm that the process is working correctly
      assert :updated == ExampleWorker.get(new_pid)

      # Confirm that the registry has 1 process
      assert 1 == GenRegistry.count(ExampleWorker)
    end
  end

  describe "stop/2" do
    setup [:start_registry]

    test "unknown id" do
      assert {:error, :not_found} = GenRegistry.stop(ExampleWorker, :unknown)
    end

    test "known id" do
      # Start a process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the process is alive
      assert Process.alive?(pid)

      # Confirm that the registry has 1 process
      assert 1 == GenRegistry.count(ExampleWorker)

      # Stop the process
      assert :ok = GenRegistry.stop(ExampleWorker, :test_id)

      # Confirm that the process is dead
      refute Process.alive?(pid)

      # Confirm that the registry has 0 processes
      assert 0 == GenRegistry.count(ExampleWorker)
    end
  end

  describe "count/1" do
    setup [:start_registry]

    test "empty registry" do
      assert 0 == GenRegistry.count(ExampleWorker)
    end

    test "populated registry" do
      for i <- 1..5 do
        assert {:ok, _} = GenRegistry.lookup_or_start(ExampleWorker, i)
        assert i == GenRegistry.count(ExampleWorker)
      end
    end

    test "decreases when process stopped" do
      # Confirm the initial count for the empty registry
      assert 0 == GenRegistry.count(ExampleWorker)

      # Start a process
      assert {:ok, _} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the count incremented for the new process
      assert 1 == GenRegistry.count(ExampleWorker)

      # Stop the process
      assert :ok = GenRegistry.stop(ExampleWorker, :test_id)

      # Confirm that the count decremented to account for the process stopping
      assert 0 == GenRegistry.count(ExampleWorker)
    end

    test "decreases when process exits" do
      # Confirm the initial count for the empty registry
      assert 0 == GenRegistry.count(ExampleWorker)

      # Start a process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the count incremented for the new process
      assert 1 == GenRegistry.count(ExampleWorker)

      # Force the process to exit
      GenServer.stop(pid)

      # Confirm that the count decremented to account for the process exiting
      assert wait_until(fn ->
               GenRegistry.count(ExampleWorker) == 0
             end)
    end
  end

  describe "reduce/3" do
    setup [:start_registry]

    def collect({id, pid}, acc) do
      [{id, pid} | acc]
    end

    test "empty registry, empty accumulator" do
      assert [] == GenRegistry.reduce(ExampleWorker, [], &collect/2)
    end

    test "empty registry, populated accumulator" do
      acc = [1, 2, 3]

      assert ^acc = GenRegistry.reduce(ExampleWorker, acc, &collect/2)
    end

    test "populated registry, empty accumulator" do
      expected =
        for i <- 1..5 do
          assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, i)
          {i, pid}
        end

      # Note: Reduce doesn't guarantee ordering, the sort makes comparison simpler
      actual =
        ExampleWorker
        |> GenRegistry.reduce([], &collect/2)
        |> Enum.sort()

      assert expected == actual
    end

    test "populated registry, populated accumulator" do
      acc = [{1, nil}, {2, nil}, {3, nil}]

      expected =
        for i <- 4..5, into: acc do
          assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, i)
          {i, pid}
        end

      actual =
        ExampleWorker
        |> GenRegistry.reduce(acc, &collect/2)
        |> Enum.sort()

      assert expected == actual
    end
  end

  describe "registered process exit" do
    setup [:start_registry]

    test "count decrements" do
      # Start a process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the process is alive
      assert Process.alive?(pid)

      # Confirm that the registry has 1 process
      assert 1 == GenRegistry.count(ExampleWorker)

      # Force the process to exit
      Process.exit(pid, :kill)

      # Confirm that the process has exited
      refute Process.alive?(pid)

      # Wait for the registry to process the exit
      assert wait_until(fn ->
               GenRegistry.count(ExampleWorker) == 0
             end)

      # Confirm that the registry has 0 processes
      assert 0 == GenRegistry.count(ExampleWorker)
    end

    test "id is removed from the registry" do
      # Start a process
      assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :test_id)

      # Confirm that the process is alive
      assert Process.alive?(pid)

      # Confirm that the registry knows about the id
      assert {:ok, ^pid} = GenRegistry.lookup(ExampleWorker, :test_id)

      # Force the process to exit
      Process.exit(pid, :kill)

      # Confirm that the process has exited
      refute Process.alive?(pid)

      # Wait for the registry to process the exit
      assert wait_until(fn ->
               GenRegistry.count(ExampleWorker) == 0
             end)

      # Confirm that the registry no longer knows about the id
      assert {:error, :not_found} = GenRegistry.lookup(ExampleWorker, :test_id)
    end
  end

  describe "stopping a registry" do
    setup [:start_registry]

    test "exits all registered processes" do
      registry = Process.whereis(ExampleWorker)

      # Start some processes
      pids =
        for i <- 1..5 do
          assert {:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, i)
          pid
        end

      # Confirm that all processes are alive
      assert Enum.all?(pids, &Process.alive?/1)

      # Stop the registry
      assert true == Process.exit(registry, :normal)

      # Wait for the registry to die
      assert wait_until(fn ->
               not Process.alive?(registry)
             end)

      # Confirm that all process are dead
      refute Enum.any?(pids, &Process.alive?/1)
    end
  end

  describe "supervising a registry via module child spec" do
    test "invalid spec, no arguments" do
      assert_raise KeyError, "key :worker_module not found in: []", fn ->
        Supervisor.start_link([GenRegistry], strategy: :one_for_one)
      end
    end

    test "invalid spec, no :worker_module argument" do
      assert_raise KeyError, "key :worker_module not found in: [test_key: :test_value]", fn ->
        Supervisor.start_link([{GenRegistry, test_key: :test_value}], strategy: :one_for_one)
      end
    end

    test "valid module child spec" do
      assert {:ok, pid} =
               Supervisor.start_link(
                 [
                   {GenRegistry, worker_module: ExampleWorker}
                 ],
                 strategy: :one_for_one
               )

      assert Supervisor.count_children(pid) == %{
               active: 1,
               specs: 1,
               supervisors: 1,
               workers: 0
             }

      assert [{ExampleWorker, _, :supervisor, _}] = Supervisor.which_children(pid)
    end
  end

  describe "supervising a registry via pre-1.5 Supervisor.Spec" do
    test "functions as expected" do
      # Note: See ExampleSupervisor in test_helpers.exs to see how this works
      assert {:ok, pid} = ExampleSupervisor.start_link()

      assert Supervisor.count_children(pid) == %{
               active: 1,
               specs: 1,
               supervisors: 1,
               workers: 0
             }

      assert [{ExampleWorker, _, :supervisor, _}] = Supervisor.which_children(pid)
    end
  end
end

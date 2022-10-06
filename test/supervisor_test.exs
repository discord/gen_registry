defmodule Supervisor.Test do
  use ExUnit.Case

  describe "pre-1.5 specs" do
    test "valid spec" do
      children = [
        GenRegistry.Spec.child_spec(ExampleWorker)
      ]

      {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

      assert Supervisor.count_children(supervisor_pid) == %{
               active: 1,
               specs: 1,
               supervisors: 1,
               workers: 0
             }

      assert [{ExampleWorker, _, :supervisor, _}] = Supervisor.which_children(supervisor_pid)

      Supervisor.stop(supervisor_pid)
    end

    test "can customize the name and run multiple registries for the same module" do
      children = [
        GenRegistry.Spec.child_spec(ExampleWorker, name: ExampleWorker.A),
        GenRegistry.Spec.child_spec(ExampleWorker, name: ExampleWorker.B)
      ]

      {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

      assert Supervisor.count_children(supervisor_pid) == %{
               active: 2,
               specs: 2,
               supervisors: 2,
               workers: 0
             }

      children = Supervisor.which_children(supervisor_pid)

      assert Enum.find(children, &match?({ExampleWorker.A, _, :supervisor, _}, &1))
      assert Enum.find(children, &match?({ExampleWorker.B, _, :supervisor, _}, &1))

      Supervisor.stop(supervisor_pid)
    end
  end

  describe "modern specs" do
    test "invalid spec, no arguments" do
      assert_raise KeyError, "key :worker_module not found in: []", fn ->
        children = [
          GenRegistry
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end
    end

    test "invalid spec, no :worker_module argument" do
      assert_raise KeyError, "key :worker_module not found in: [test_key: :test_value]", fn ->
        children = [
          {GenRegistry, test_key: :test_value}
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end
    end

    test "valid spec" do
      children = [
        {GenRegistry, worker_module: ExampleWorker}
      ]

      {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

      assert Supervisor.count_children(supervisor_pid) == %{
               active: 1,
               specs: 1,
               supervisors: 1,
               workers: 0
             }

      assert [{ExampleWorker, _, :supervisor, _}] = Supervisor.which_children(supervisor_pid)

      Supervisor.stop(supervisor_pid)
    end

    test "can customize the name and run multiple registries for the same module" do
      children = [
        {GenRegistry, worker_module: ExampleWorker, name: ExampleWorker.A},
        {GenRegistry, worker_module: ExampleWorker, name: ExampleWorker.B}
      ]

      {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

      assert Supervisor.count_children(supervisor_pid) == %{
               active: 2,
               specs: 2,
               supervisors: 2,
               workers: 0
             }

      children = Supervisor.which_children(supervisor_pid)

      assert Enum.find(children, &match?({ExampleWorker.A, _, :supervisor, _}, &1))
      assert Enum.find(children, &match?({ExampleWorker.B, _, :supervisor, _}, &1))

      Supervisor.stop(supervisor_pid)
    end
  end
end

# GenRegistry

[![CI](https://github.com/discord/gen_registry/workflows/CI/badge.svg)](https://github.com/discord/gen_registry/actions)
[![Hex.pm Version](http://img.shields.io/hexpm/v/gen_registry.svg?style=flat)](https://hex.pm/packages/gen_registry)
[![Hex.pm License](http://img.shields.io/hexpm/l/gen_registry.svg?style=flat)](https://hex.pm/packages/gen_registry)
[![HexDocs](https://img.shields.io/badge/HexDocs-Yes-blue)](https://hexdocs.pm/gen_registry)

`GenRegistry` provides a simple interface for managing a local registry of processes.

## Installation

Add `GenRegistry` to your dependencies.

```elixir
def deps do
  [
    {:gen_registry, "~> 1.0"}
  ]
end
```

## Why GenRegistry?

`GenRegistry` makes it easy to manage one process per id, this allows the application code to work with a more natural id (user_id, session_id, phone_number, etc), but still easily retrieve and lazily spawn processes.

### Example: Phone Number Blacklist

In our example we have some arbitrary spam deflection system where each phone number is allowed to define its own custom rules.  To make sure our application stays simple we encapsulate the blacklisting logic in a GenServer which handles caching, loading, saving blacklist rules.

With `GenRegistry` we don't need to worry about carefully keeping track of Blacklist pids for each phone number.  The phone number (normalized) makes a natural id for the `GenRegistry`. `GenRegistry` will also manage the lifecycle and supervision of these processes, allowing us to write simplified code like this.

```elixir
def place_call(sender, recipient) do
  # Get the recipients Blacklist GenServer
  {:ok, blacklist} = GenRegistry.lookup_or_start(Blacklist, recipient, [recipient])

  if Blacklist.allow?(blacklist, sender) do
    {:ok, :place_call}
  else
    {:error, :reject_call}
  end
end
```

Does the recipient have a GenServer already running? If so then the pid will be returned, if not then `Blacklist.start_link(recipient)` will be called, the resulting pid will be registered with the `GenRegistry` under the recipient phone number and the pid returned.

## Supervising the GenRegistry

`GenRegistry` works best as part of a supervision tree.  `GenRegistry` provides support for pre-1.5 `Supervisor.Spec` style child specs and the newer module based child specs.

### Module-Based Child Spec

Introduced in Elixir 1.5, module-based child specs are the preferred way of defining a Supervisor's children.  `GenRegistry.child_spec/1` is compatible with module-based child specs.

Here's how to add a supervised `GenRegistry` to your application's `Supervisor` that will manage an example module called `ExampleWorker`.

```elixir
def children do
  [
    {GenRegistry, worker_module: ExampleWorker}
  ]
end
```

`worker_module` is required, any other arguments will be used as the options for `GenServer.start_link/3` when starting the `GenRegistry`

### Supervisor.Spec Child Spec

_This style was deprecated in Elixir 1.5, this functionality is provided for backwards
compatibility._

If pre-1.5 style child specs are needed, the `GenRegistry.Spec` module provides a helper `GenRegistry.Spec.child_spec/2` which will generate the appropriate spec to manage a `GenRegistry` process.

Here's how to add a supervised `GenRegistry` to your application's `Supervisor` that will manage an example module called `ExampleWorker`.

```elixir
def children do
  [
    GenRegistry.Spec.child_spec(ExampleWorker)
  ]
end
```

The second argument is a `Keyword` of options that will be passed as the options for `GenServer.start_link/3` when starting the `GenRegistry`

## Basic Usage

`GenRegistry` uses some conventions to make it easy to work with.  `GenRegistry` will use `GenServer.start_link/3`'s `:name` facility to give the `GenRegistry` the same name as the `worker_module`.  `GenRegistry` will also name the `ETS` table after the `worker_module`.

These two conventions together mean almost every function in the `GenRegistry` API can be called with the `worker_module` as the first argument and work as expected.

Building off of the above supervision section, let's assume that we've start a `GenRegistry` to manage the `ExampleWorker` module.

### Customizing the Name

The conventions covered in the last section work for most cases but what happens if you want to use the same `worker_module` for multiple logical registries.  This is where custom names come in.

Simply provide a `name` argument.

For pre-1.5 child specifications

```elixir
def children do
  [
    GenRegistry.Spec.child_spec(ExampleWorker, name: ExampleWorker.Read)
    GenRegistry.Spec.child_spec(ExampleWorker, name: ExampleWorker.Write)
  ]
end
```

For Module-Based child specifications

```elixir
def children do
  [
    {GenRegistry, worker_module: ExampleWorker, name: ExampleWorker.Read},
    {GenRegistry, worker_module: ExampleWorker, name: ExampleWorker.Write},
  ]
end
```

Now simply use the `name` in place of the `worker_module` when calling any of the functions outlined below.
### Starting a new process

`GenRegistry` makes it easy to idempotently start worker processes using the `GenRegistry.lookup_or_start/4` function.

```elixir
{:ok, pid} = GenRegistry.lookup_or_start(ExampleWorker, :example_id)
```

If `:example_id` is already bound to a running process, then that process's pid is returned. Otherwise a new process is started.  Workers are started by calling the `worker_module`'s `start_link` function, `GenRegistry.lookup_or_start/4` accepts an optional third argument, a list of arguments to pass to `start_link`, the default is to pass no arguments.

If there is an error spawning a new process, `{:error, reason}` is returned.

### Retrieving the pid for an id

`GenRegistry` makes it easy to get the pid associated with an id using the `GenRegistry.lookup/2` function.

This function reads from the ETS table in the current process's context avoiding a GenServer call.

```elixir
case GenRegistry.lookup(ExampleWorker, :example_id) do
  {:ok, pid} ->
    # Do something interesting with pid

  {:error, :not_found} ->
    # :example_id isn't bound to any running process.
end
```

### Stopping a process by id

`GenRegistry` also supports stopping a child process using the `GenRegistry.stop/2` function.

```elixir
case GenRegistry.stop(ExampleWorker, :example_id) do
  :ok ->
    # Process was successfully stopped

  {:error, :not_found} ->
    # :example_id isn't bound to any running process.
end
```

### Counting processes

`GenRegistry` manages all the processes it has spawned, it is capable of reporting how many processes it is currently managing using the `GenRegistry.count/1` function.

```elixir
IO.puts("There are #{GenRegistry.count(ExampleWorker)} ExampleWorker processes")
```

### Bulk Operations

`GenRegistry` provides a facility for reducing a function over every process using the `GenRegistry.reduce/3` function.  This function accepts an accumulator and ultimately returns the accumulator.

```elixir
{max_id, max_pid} =
    GenRegistry.reduce(ExampleWorker, {nil, -1}, fn
      {id, pid}, {_, current}=acc ->
        value = ExampleWorker.foobars(pid)
        if value > current do
          {id, pid}
        else
          acc
        end
    end)
```

### More Details

All the methods of GenRegistry are documented and spec'd, the tests also provide example code for how to use GenRegistry.

## Configuration

`GenRegistry` only has a single configuration setting, `:gen_registry` `:gen_module`.  This is the module to use to when performing `GenServer` calls, it defaults to `GenServer`.

## Documentation

Documentation is [hosted on hexdocs](https://hexdocs.pm/gen_registry).

## Running the Tests

GenRegistry ships with a full suite of tests, these are normal ExUnit tests.

```console
$ mix tests
```

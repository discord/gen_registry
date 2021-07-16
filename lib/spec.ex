defmodule GenRegistry.Spec do
  @moduledoc """
  GenRegistry.Spec provides helpers for pre-1.5 supervision.

  Starting in Elixir 1.5 the preferred way to define child specs changed from using the now
  deprecated `Supervisor.Spec` module to using module-based child specs.  This is a legacy support
  module for pre-1.5 spec generation
  """

  import Supervisor.Spec, warn: false

  @doc """
  Returns a pre-1.5 child spec for GenRegistry
  """
  @spec child_spec(worker_module :: module, opts :: Keyword.t()) :: Supervisor.Spec.spec()
  def child_spec(worker_module, opts \\ []) do
    opts = Keyword.put_new(opts, :name, worker_module)

    supervisor(GenRegistry, [worker_module, opts], id: opts[:name])
  end
end

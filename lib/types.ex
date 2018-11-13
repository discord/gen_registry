defmodule GenRegistry.Types do
  @typedoc """
  GenRegistry register a running process to an id.

  This id can be any valid Erlang Term, the id type is provided to clarify when an argument is
  intended to be an id.
  """
  @type id :: term
end

use Mix.Config

config :gen_registry,
  gen_module: GenServer

import_config "#{Mix.env()}.exs"

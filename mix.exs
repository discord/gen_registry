defmodule GenRegistry.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gen_registry,
      version: "1.0.0",
      elixir: "~> 1.2",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [
      name: "GenRegistry",
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/discordapp/gen_registry"
    ]
  end

  defp package do
    [
      name: :gen_registry,
      description: "GenRegistry provides simple management of a local registry of processes.",
      maintainers: ["Discord Core Infrastructure"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/discordapp/gen_registry"
      }
    ]
  end
end

defmodule BtNodeEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :bt_node_ex,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      # Add source URL for documentation
      source_url: "https://github.com/xenomorphtech/btnode_ex",
      # Add homepage URL
      homepage_url: "https://github.com/xenomorphtech/btnode_ex",
      # Add docs configuration if you want to generate documentation
      docs: [
        main: "README",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Add ex_doc for documentation generation
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    BtNodeEx - Behavior Tree implementation in Elixir.
    """
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/xenomorphtech/btnode_ex"
      },
      maintainers: ["Your Name"],  # Replace with actual maintainer name
    ]
  end
end

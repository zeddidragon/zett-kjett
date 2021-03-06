defmodule Zettkjett.Mixfile do
  use Mix.Project

  def project do
    [ app: :zettkjett,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps() ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [ applications: applications(Mix.env),
      extra_applications: [:logger],
      mod: {ZettKjett, []} ]
  end

  defp applications :dev do
    applications(:all)
  end

  defp applications _ do
    [:httpotion, :crypto, :ssl]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [ {:httpotion, "~> 3.0.2"},
      {:tomlex, ">= 0.0.0"},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git"},
      {:json, "~> 1.0"}
    ]
  end
end

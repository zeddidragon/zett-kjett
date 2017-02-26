defmodule ZettKjett.Config do
  def start_link do
    data = File.read!("./config.toml") |> Tomlex.load
    Agent.start_link fn -> data end, name: __MODULE__
  end

  def get(f \\ &(&1)) do
    Agent.get(__MODULE__, f)
  end
end

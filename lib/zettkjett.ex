defmodule ZettKjett do
  alias ZettKjett.Config
  def start _type, _args do
    IO.puts "Welcome to ZettKjett"
    Config.start_link
    if Mix.env != :test do
      Agent.start_link fn -> connect() end, name: __MODULE__
      interface()
    end
    {:ok, self()}
  end

  def connect do
    protocols = Config.get[:Protocols] || %{}
    for {protocol, config} <- protocols, config[:enabled] do
      IO.puts "Connecting to #{protocol}..."
      ZettKjett.Protocol.start_link protocol
    end
  end

  def interface do
    ZettKjett.Interfaces.IO.start_link
  end

  def flat_map_protocols cb do
    Agent.get __MODULE__, fn protocols ->
      Enum.flat_map protocols, fn protocol ->
        for result <- cb.(protocol) do
          {protocol, result}
        end
      end
    end
  end

  def friends do
    flat_map_protocols fn p -> p.friends end
  end

end

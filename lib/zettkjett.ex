defmodule ZettKjett do
  alias ZettKjett.Config
  def start _type, _args do
    IO.puts "Welcome to ZettKjett"
    Config.start_link
    if Mix.env != :test do
      pid = Task.start_link, fn -> message_loop() end
      Agent.start_link fn -> %{protocols: connect(pid)} end, name: __MODULE__
      interface()
      send self(), "This is a message"
    end
    {:ok, self()}
  end

  def message_loop do
    receive do
      message ->
        IO.puts "Yay we got mail!"
        message |> inspect |> IO.puts
    end
    message_loop()
  end

  def connect listener do
    protocols = Config.get[:Protocols] || %{}
    for {protocol, config} <- protocols, config[:enabled] do
      IO.puts "Connecting to #{protocol}..."
      ZettKjett.Protocol.start_link protocol, listener
    end
  end

  @interface ZettKjett.Interface
  def interface do
    {:ok, pid} = ZettKjett.Interfaces.IO.start_link
    Process.register pid, @interface
  end

  def flat_map_protocols cb do
    Agent.get __MODULE__, fn %{protocols: protocols} ->
      Enum.flat_map protocols, fn protocol ->
        Enum.map cb.(protocol), fn result -> {protocol, result} end
      end
    end
  end

  def me do
    Agent.get __MODULE__, fn
      %{protocol: protocol} -> protocol.me
      _ -> nil
    end
  end

  def friends do
    flat_map_protocols fn p -> p.friends end
  end

  def tell string do
    Agent.get __MODULE__, fn
      %{protocol: protocol, chat: chat} -> protocol.tell! chat, string
      _ -> send @interface, {:error, :no_chat_joined}
    end
  end

  def tell {protocol, {chat, user}}, string do
    Agent.update __MODULE__,
      &Map.merge(&1, %{chat: chat, protocol: protocol})
    send @interface, {:join_chat, protocol, chat, user}
    protocol.tell! chat, string
  end
end

defmodule ZettKjett do
  alias ZettKjett.{Config, Protocol}
  @state __MODULE__
  @interface ZettKjett.Interface

  def start _type, _args do
    IO.puts "Welcome to ZettKjett"
    Config.start_link
    if Mix.env != :test do
      {:ok, pid} = Task.start_link fn -> message_loop() end
      Agent.start_link fn -> %{protocols: connect(pid)} end, name: @state
      interface()
      state_loop()
    end
    {:ok, self()}
  end

  def message_loop do
    receive do
      message -> send @interface, message
    end
    message_loop()
  end

  def state_loop do
    receive do
      message ->
        IO.puts "State loop message"
        message |> inspect |> IO.puts
    end
  end

  def connect listener do
    protocols = Config.get[:Protocols] || %{}
    Protocol.start_link
    for {protocol, config} <- protocols, config[:enabled] do
      IO.puts "Connecting to #{protocol}..."
      Protocol.connect protocol, listener
    end
  end

  def interface do
    {:ok, pid} = ZettKjett.Interfaces.IO.start_link
    Process.register pid, @interface
  end

  def flat_map_protocols cb do
    Agent.get @state, fn %{protocols: protocols} ->
      Enum.flat_map protocols, fn protocol ->
        Enum.map cb.(protocol), fn result -> {result, protocol} end
      end
    end
  end

  def protocols do
    Agent.get @state, &Map.get(&1, :protocols)
  end

  def protocol do
    Agent.get @state, fn
      %{protocol: ret} -> ret
      _ -> nil
    end
  end

  def switch protocol do
    Agent.update @state, &Map.put(&1, :protocol, protocol)
    send @interface, {{:switch_protocol}, protocol}
  end

  def me do
    Protocol.me protocol()
  end

  def nick name do
    if proto = protocol() do
    if !Protocol.nick proto, name do
      send @interface, {{:error, :global_nick_not_implemented}, proto}
    end
    else
      send @interface, {{:error, :no_protocol_selected}, nil}
    end
  end

  def friends do
    flat_map_protocols &Protocol.friends/1
  end

  def tell string do
    Agent.get @state, fn
      %{protocol: protocol, chat: chat} ->
        Protocol.tell protocol, chat, string
      _ -> send @interface, {{:error, :no_chat_joined}, nil}
    end
  end
  def tell {{user, chat}, protocol}, string do
    Agent.update @state, &Map.merge(&1, %{chat: chat, protocol: protocol})
    send @interface, {{:join_chat, chat, user}, protocol}
    Protocol.tell protocol, chat, string
  end

  def history do
    Agent.get @state, fn
      %{protocol: protocol, chat: chat} ->
        history protocol, chat
      _ ->
        send @interface, {{:error, :no_protocol_selected}, nil}
        []
    end
  end
  def history protocol, chat do
    Protocol.history protocol, chat
  end

  def channels do
    flat_map_protocols Protocol.channels/1
  end
end

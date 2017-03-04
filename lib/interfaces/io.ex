defmodule ZettKjett.Interfaces.IO do
  def start_link do
    Task.start_link &input_loop/0
    Task.start_link &message_loop/0
  end
  
  defp system message do
    IO.puts "\r=== " <> message 
  end
  defp error message do
    IO.puts "\rERROR: " <> message
  end

  def message_loop do
    receive do
      {{:switch_protocol}, protocol} ->
        system "Protocol changed to " <> protocol_name(protocol)
      {{:join_chat, _, user}, _} ->
        system "Now talking with " <> user.name
      {{:message, _, user, message}, _} ->
        IO.puts "\r <#{user.name}> " <> message.message
      {{:nick, user}, _} ->
        system "Nick changed to " <> user.name
      message ->
        message |> inspect |> system
    end
    message_loop()
  end

  def input_loop do
    me = ZettKjett.me
    prompt = me && me.name || ""
    IO.gets(prompt <> "> ")
      |> String.trim
      |> parse_input
    input_loop()
  end

  def parse_input input do
    if "/" == String.first input do
      [cmd | args] = input
        |> String.slice(1..-1)
        |> String.split
      run_command String.downcase(cmd), args
    else
      message input
    end
  end

  defp compare_friends friends, string do
    string = String.downcase string
    Enum.sort_by friends, fn {{user, _}, _} ->
      user.name
        |> String.downcase
        |> String.jaro_distance(string)
        |> Kernel.-
    end
  end

  defp protocol_name protocol do
    to_string protocol
  end

  defp compare_protocols protocols, string do
    string = String.downcase string
    Enum.sort_by protocols, fn protocol ->
      protocol
        |> protocol_name()
        |> String.downcase
        |> String.jaro_distance(string)
        |> Kernel.-
    end
  end

  defp tell_friend friend, string do
    ZettKjett.tell friend, string
  end
  
  defp run_command "protocols", _ do
    protocols()
  end

  defp run_command "switch", [target | _] do
    switch target
  end
  defp run_command "switch", _ do
    error "Usage: \"/switch <protocol>\""
  end

  defp run_command "friends", _ do
    friends()
  end

  defp run_command "tell", [target | args] do
    message target, Enum.join(args, " ")
  end
  defp run_command "tell", _ do
    error "Usage: \"/tell <friend> [<message>]\""
  end

  defp run_command "history", _ do
    for {user, message} <- Enum.reverse ZettKjett.history do
      IO.puts "<#{user.name}> #{message.message}"
    end
  end

  defp run_command "nick", [] do
    error "Usage: \"/nick <new name>\""
  end
  defp run_command "nick", args do
    nick Enum.join(args, " ")
  end

  defp run_command unknown, _ do
    error "Unknown function: /" <> unknown
  end

  def protocols do
    system "PROTOCOLS"
    for protocol <- ZettKjett.protocols do
      system " " <> protocol_name(protocol)
    end
  end

  def switch target do
    ZettKjett.protocols
      |> compare_protocols(target)
      |> hd()
      |> ZettKjett.switch()
  end

  def friends do
    system "FRIENDS"
    for {{user, _}, _} <- ZettKjett.friends do
      system " " <> user.name
    end
  end

  def nick name do
    case ZettKjett.nick name do
      {:error, message} -> message |> to_string |> error
      _ -> {:ok}
    end
  end

  defp message message do
    ZettKjett.tell message
  end

  def message target, message do
    ZettKjett.friends
      |> compare_friends(target)
      |> hd()
      |> tell_friend(message)
  end
end

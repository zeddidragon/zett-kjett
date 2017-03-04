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
    Enum.sort_by friends, fn {{_, user}, _} ->
      -String.jaro_distance(String.downcase(user.name), string)
    end
  end

  defp tell_friend friend, string do
    ZettKjett.tell friend, string
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

  defp run_command "nick", [] do
    error "Usage: \"/nick <new name>\""
  end
  defp run_command "nick", args do
    nick Enum.join(args, " ")
  end

  defp run_command [unknown | _] do
    error "Unknown function: /" <> unknown
  end

  def friends do
    system "FRIENDS"
    for {{_, user}, _} <- ZettKjett.friends do
      system " " <> user.name
    end
  end

  def nick name do
    ZettKjett.nick name
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

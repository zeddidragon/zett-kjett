defmodule ZettKjett.Interfaces.IO do
  def start_link do
    Task.start_link &input_loop/0
    Task.start_link &message_loop/0
  end
  
  defp system message do
    IO.puts "=== " <> message 
  end
  defp error message do
    IO.puts "ERROR: " <> message
  end

  def message_loop do
    receive do
      {:join_chat, protocol, chat, user} ->
        system "Now talking with " <> user.name
      {:message, _, _, user, message} ->
        IO.puts "<#{user.name}>" <> message.message
      message ->
        message |> inspect |> system
    end
    message_loop()
  end

  def input_loop do
    IO.gets("> ")
      |> String.trim
      |> parse_input
    input_loop()
  end

  def parse_input input do
    if "/" == String.first input do
      input
        |> String.slice(1..-1)
        |> String.downcase
        |> String.split
        |> run_command
    else
      message input
    end
  end

  defp compare_friends friends, string do
    Enum.sort_by friends, fn {protocol, {chat, user}} ->
      -String.jaro_distance(String.downcase(user.name), string)
    end
  end

  defp tell_friend friend, string do
    ZettKjett.tell friend, string
  end

  defp run_command ["friends" | args] do
    friends()
  end
  defp run_command ["tell", target | args] do
    message target, Enum.join(args, " ")
  end

  defp run_command ["tell" | args] do
    error "Usage: \"/tell <friend> [<message>]\""
  end

  defp run_command [unknown | args] do
    error "Unknown function: /" <> unknown
  end

  def friends do
    system "FRIENDS"
    for {chat, user} <- ZettKjett.friends do
      system " " <> user.name
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

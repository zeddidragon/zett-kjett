defmodule ZettKjett.Interfaces.IO do
  def start_link do
    Task.start_link do
      input_loop()
    end
  end

  def input_loop do
    case String.slice IO.gets("> "), 0..-2 do
      "Hi" -> IO.puts "Hi! We're talking!"
      "/friends" -> friends()
      any -> IO.puts any
    end
    input_loop()
  end

  def friends do
    IO.puts "==FRIENDS=="
    for {protocol, {chat, user}} <- ZettKjett.friends do
      IO.puts " " <> user.name
    end
  end
end

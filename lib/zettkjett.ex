defmodule ZettKjett do
  alias ZettKjett.Config
  def start _type, _args do
    IO.puts "Welcome to ZettKjett"
    Config.start_link
    if Mix.env != :test do
      connect()
    end
    ZettKjett.Interfaces.Curses.start_link
    {:ok, self()}
  end

  def connect do
    for {protocol, config} <- (Config.get[:Protocols] || %{}) do
      if config[:enabled] do
        IO.puts "Connecting to #{protocol}..."
        ZettKjett.Protocol.start_link protocol
      end
    end
  end
end

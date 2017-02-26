defmodule ZettKjett do
  def start _type, _args do
    IO.puts "Welcome to ZettKjett"
    ZettKjett.Config.start_link
  end
end

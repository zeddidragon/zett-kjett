defmodule ZettKjett.Protocol do
  def start_link name do
    module = Module.concat([ZettKjett, Protocols, name])
    module.start_link self()
  end
end

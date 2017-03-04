defmodule ZettKjett.Protocol do
  def start_link name, listener do
    module = Module.concat([ZettKjett, Protocols, name])
    module.start_link listener
    module
  end
end

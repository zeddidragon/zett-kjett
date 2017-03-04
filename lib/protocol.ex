defmodule ZettKjett.Protocol do
  def start_link name, listener do
    module = Module.concat([ZettKjett, Protocols, name])
    {:ok, pid} = Task.start_link fn -> message_loop(module, listener) end
    module.start_link pid
    module
  end

  def message_loop module, listener do
    receive do
      message -> send listener, {message, module}
    end
    message_loop module, listener
  end
end

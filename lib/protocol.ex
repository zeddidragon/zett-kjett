defmodule ZettKjett.Protocol do
  def start_link do
    Agent.start_link fn -> %{} end, name: __MODULE__
  end

  def connect name, listener do
    module = Module.concat([ZettKjett, Protocols, name])
    {:ok, pid} =
      Task.start_link fn ->
        cache = Agent.start_link fn -> %{} end
        message_loop(module, name, listener, cache)
      end
    module.start_link pid
    Agent.update __MODULE__, &Map.put(&1, name, {module, pid})
    name
  end

  defp message_loop protocol, module, listener, cache do
    receive do
      message -> send listener, {message, module}
    end
    message_loop protocol, module, listener, cache
  end

  defp get_protocol name do
    Agent.get __MODULE__, &Map.get(&1, name)
  end

  defp cache protocol, key, value do
    {module, pid} = get_protocol protocol
    Agent.update pid, &Map.put(&1, key, value)
  end
  defp cached protocol, key, getter do
    {module, pid} = get_protocol protocol
    Agent.update pid, &Map.put_new_lazy(&1, key, fn -> getter.(module) end)
    Agent.get pid, &Map.get(&1, key)
  end

  def me protocol do
    cached protocol, :me, &me!/1
  end
  defp me! protocol do
    {module, pid} = get_protocol protocol
    module.me
  end

  def friends protocol do
    cached protocol, :friends, &friends!/1
  end
  defp friends! protocol do
    {module, pid} = get_protocol protocol
    module.friends
  end
end

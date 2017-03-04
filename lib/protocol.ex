defmodule ZettKjett.Protocol do
  def start_link do
    Agent.start_link fn -> %{} end, name: __MODULE__
  end

  def connect name, listener do
    module = Module.concat([ZettKjett, Protocols, name])
    {:ok, cache} =
      Agent.start_link fn -> %{} end
    {:ok, loop} =
      Task.start_link fn ->
        message_loop(module, name, listener, cache)
      end
    {:ok, _} = module.start_link loop
    Agent.update __MODULE__, &Map.put(&1, name, {module, loop, cache})
    name
  end

  defp message_loop module, protocol, listener, cache do
    receive do msg ->
      case msg do
        {:message, chat, user, message} ->
          add_message protocol, chat, {user, message}
        _ ->
          if Mix.env == :dev do
            IO.puts "Unknown protocol message for #{protocol}"
            IO.inspect(msg)
          end
      end
      send listener, {msg, module}
    end
    message_loop module, protocol, listener, cache
  end

  defp add_message protocol, chat, entry do
    messages = history protocol, chat
    cache protocol, :history, [entry | messages]
  end

  defp get_protocol name do
    Agent.get __MODULE__, &Map.get(&1, name)
  end

  defp cache protocol, key, value do
    {_, _, cache} = get_protocol protocol
    Agent.update cache, &Map.put(&1, key, value)
  end
  defp cached protocol, key, getter do
    {module, _, cache} = get_protocol protocol
    Agent.update cache, &Map.put_new_lazy(&1, key, fn -> getter.(module) end)
    Agent.get cache, &Map.get(&1, key)
  end

  def me protocol do
    protocol && cached protocol, :me, &me!/1
  end
  defp me! module do
    module.me
  end

  def nick protocol, name do
    {module, _, _} = get_protocol protocol
    if function_exported? module, :nick, 1 do
      module.nick name
    end
  end

  def friends protocol do
    cached protocol, :friends, &friends!/1
  end
  defp friends! module do
    module.friends
  end

  def tell protocol, chat, message do
    {module, _, _} = get_protocol protocol
    module.tell chat, message
  end

  def history protocol, chat do
    cached protocol, :history, &history!(&1, chat)
  end
  defp history! module, chat do
    module.history chat
  end
end

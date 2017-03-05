defmodule ZettKjett.Protocol do
  @enforce_keys [:module, :protocol, :listener, :cache]
  defstruct [
    module: nil,
    protocol: nil,
    listener: nil,
    cache: nil
  ]

  def start_link do
    Agent.start_link fn -> %{} end, name: __MODULE__
  end

  def connect name, listener do
    module = Module.concat([ZettKjett, Protocols, name])
    {:ok, cache} =
      Agent.start_link fn -> %{} end
    {:ok, loop} =
      Task.start_link fn ->
        message_loop %{
          module: module,
          protocol: name,
          listener: listener,
          cache: cache
        }
      end
    {:ok, _} = module.start_link loop
    Agent.update __MODULE__, &Map.put(&1, name, {module, loop, cache})
    name
  end

  defp message_loop state do
    receive do msg ->
      if handle_message(msg, state) do
        send state.listener, {msg, state.protocol}
      end
      message_loop state
    end
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

  def handle_message {:me, user}, state do
    cache state.protocol, :me, user
    :ok
  end

  def handle_message {:friends, friends}, state do
    cache state.protocol, :friends, friends
    :ok
  end

  def handle_message {:message, chat, user, entry}, state do
    messages = history state.protocol, chat
    cache state.protocol, :history, [{user, entry} | messages]
    :ok
  end

  def handle_message unknown, state do
    if Mix.env == :dev do
      IO.puts "Unknown protocol message for #{state.protocol}"
      ZettKjett.Utils.inspect(unknown)
    end
    nil
  end
end

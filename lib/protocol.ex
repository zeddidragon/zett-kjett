defmodule ZettKjett.Protocol do
  alias ZettKjett.Models.{Server, Channel, User, Message}
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
      case handle_message msg, state do
        {:ok} ->
          send state.listener, {msg, state.protocol}
        {:use, this} ->
          send state.listener, {this, state.protocol}
        _ ->
          :ok
      end
    end
    message_loop state
  end

  defp get_protocol name do
    Agent.get __MODULE__, &Map.get(&1, name)
  end
  defp get_cache name do
    elem get_protocol(name), 2
  end

  defp cache protocol, key, value do
    Agent.update get_cache(protocol), &Map.put(&1, key, value)
  end
  defp cached protocol, key, getter do
    {module, _, cache} = get_protocol protocol
    Agent.update cache, &Map.put_new_lazy(&1, key, fn -> getter.(module) end)
    Agent.get cache, &Map.get(&1, key)
  end

  defp get_model protocol, model, id do
    get_cache(protocol)
      |> Agent.get(&get_in(&1, [model, id]))
  end
  defp add_model protocol, model do
    update = &Map.put(&1, model.id, model)
    get_cache(protocol)
      |> Agent.update(&Map.update(&1, model.__struct__, %{}, update))
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
    add_model state.protocol, user
    cache state.protocol, :me, user
    {:ok}
  end

  def handle_message {:friends, friends}, state do
    for {user, channel} <- friends do
      add_model state.protocol, user
      add_model state.protocol, channel
    end
    cache state.protocol, :friends, friends
    {:ok}
  end

  def handle_message {:message, user, entry}, state do
    add_model state.protocol, user
    channel = get_model state.protocol, Channel, entry.channel_id
    messages = history state.protocol, channel
    cache state.protocol, :history, [{user, entry} | messages]
    {:use, {:message, channel, user, entry}}
  end

  def handle_message unknown, state do
    if Mix.env == :dev do
      IO.puts "Unknown protocol message for #{state.protocol}"
      ZettKjett.Utils.inspect(unknown)
    end
    {:hush}
  end
end

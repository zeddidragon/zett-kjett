defmodule ZettKjett.Utils.Socket do
  alias ZettKjett.Utils
  @behaviour :websocket_client_handler
  def start_link url, listener \\ self() do
    :websocket_client.start_link String.to_charlist(url), __MODULE__, [listener]
  end
  
  def init [listener], _conn_state do
    {:ok, listener}
  end

  def cast socket_pid, data do
    :websocket_client.cast socket_pid, {:binary, :erlang.term_to_binary(data)}
  end

  def websocket_handle {:binary, data}, _conn_state, listener do
    send listener, :erlang.binary_to_term(data)
    {:ok, listener}
  end

  # :websocket_client handles ping automatically
  def websocket_handle {:ping, ""}, _conn_state, _listener do
    {:ok, listener}
  end

  def websocket_handle packet, _conn_state, _listener do
    Utils.inspect packet, label: "Socket Packet"
    {:ok, listener}
  end

  # TODO: Find out when info is called
  def websocket_info packet, _conn_state, listener do
    Utils.inspect packet, label: "Info Packet"
    {:ok, listener}
  end

  def websocket_terminate reason, _conn_state, _listener do
    Utils.inspect reason, label: "WS Disconnect" 
    :ok
  end
end

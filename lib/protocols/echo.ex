defmodule ZettKjett.Protocols.Echo do
  @behaviour ZettKjett.Protocols.Base
  alias ZettKjett.Models.{Chat, User, Message}
  alias ZettKjett.Utils.{Socket}
  alias ZettKjett.{Utils}

  def start_link listener do
    {:ok, pid} = Task.start_link fn ->
      {:ok, socket} = connect_socket()
      loop listener, socket
    end
    Process.register pid, __MODULE__
    {:ok, pid}
  end

  def connect_socket do
    Socket.start_link "wss://echo.websocket.org", self()
  end

  defp loop listener, socket do
    receive do
      {:send_message, content} ->
        time = :os.system_time
        data = %{
          id: time,
          sent_at: time,
          content: String.to_charlist(content)
        }
        Socket.cast socket, data
      {:nick, user} ->
        send listener, {:nick, user}
      data ->
        message = %Message{
          id: data[:id],
          sent_at: data[:sent_at],
          content: to_string(data[:content])
        }
        send listener, {:message, chat(), me(), message}
    end
    loop listener, socket
  end

  def me do
    %User{id: :me, name: "Me"}
  end

  def nick name do
    send __MODULE__, {:nick, %User{id: :me, name: name}}
  end

  defp chat do
    %Chat{ id: 1 }
  end

  def friends do
    [{me(), chat()}]
  end

  def tell _, content do
    send __MODULE__, {:send_message, content}
  end

  def history _ do
    []
  end
end

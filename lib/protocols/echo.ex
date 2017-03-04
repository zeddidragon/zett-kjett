defmodule ZettKjett.Protocols.Echo do
  @behaviour ZettKjett.Protocols.Base
  alias ZettKjett.Models.{Chat, User, Message}

  def start_link listener do
    {:ok, pid} = Task.start_link fn -> loop(listener) end
    Process.register pid, __MODULE__
    {:ok, pid}
  end

  defp loop listener do
    receive do
      {:message, message}->
        send listener, {:message, chat(), me(), message}
      {:nick, user}->
        send listener, {:nick, user}
    end
    loop listener
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

  def tell _, message do
    time = :os.system_time
    message = %Message{
      id: time,
      sent_at: time,
      message: message
    }
    send __MODULE__, {:message, message}
    message
  end

  def history _ do
    []
  end
end

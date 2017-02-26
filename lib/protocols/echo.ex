defmodule ZettKjett.Protocols.Echo do
  use ZettKjett.Protocols.Base
  @behaviour ZettKjett.Protocols.Base
  alias ZettKjett.Models.{Chat, User, Message}

  def start_link! listener do
    {:ok, pid} = Task.start_link fn -> loop(listener) end
    Process.register pid, __MODULE__
    {:ok, pid}
  end

  defp loop listener do
    receive do
      {:message, message}->
        send listener, {:message, chat(), message}
    end
  end

  def me! do
    %User{id: :me, name: "Me"}
  end

  def nick! name do
    user = %User{id: :me, name: name}
    cache :me, user
    me()
  end

  defp chat do
    %Chat{
      id: 1,
      protocol: __MODULE__,
      user_id: :me
    }
  end

  def friends! do
    [chat()]
  end

  def message! message do
    time = :os.system_time
    message = %Message{
      id: time,
      sent_at: time,
      user_id: :me,
      message: message
    }
    send __MODULE__, {:message, message}
    message
  end
end

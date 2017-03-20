defmodule ZettKjett.Protocols.Echo do
  @behaviour ZettKjett.Protocols.Base
  alias ZettKjett.Models.{Channel, User, Message}
  alias ZettKjett.Utils

  def start_link listener do
    {:ok, pid} = Task.start_link fn ->
      loop listener
    end
    Process.register pid, __MODULE__
    {:ok, pid}
  end

  defp loop listener do
    receive do
      {:send_message, content} ->
        time = Utils.now
        data = %{
          id: time,
          sent_at: time,
          content: content
        }
        send self(), data
      {:nick, user} ->
        send listener, {:me, user}
      data ->
        message = %Message{
          id: data[:id],
          user_id: :me,
          channel_id: 1,
          sent_at: data[:sent_at],
          content: to_string(data[:content])
        }
        send listener, {:message, me(), message}
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
    %Channel{id: 1}
  end

  def friends do
    [me()]
  end

  def chats do
    [{chat(), [me()]}]
  end

  def tell _, content do
    send __MODULE__, {:send_message, content}
  end

  defp msg str do
    time = Utils.now
    sender = me()
    {sender, %Message{
      id: time,
      sent_at: time,
      content: str,
      user_id: sender.id,
      channel_id: 1
    }}
  end

  def history _ do
    Enum.map([
"# H1
## H2
### H3
#### H4
##### H5
###### H6

Alternatively, for H1 and H2, an underline-ish style:

Alt-H1
======

Alt-H2
------"
    ], &msg/1)
  end
end

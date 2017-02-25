defmodule ZettKjett.Chat do
  @moduledoc """
  A chat contains the conversation between the user and zero or more other
  participants.
  It can send or receive message, and contain a list of participants.
  """

  alias ZettKjett.Chat

  defstruct [messages: [], users: []]

  def start do
    Agent.start(fn -> %Chat{} end)
  end

  defp getmessages state do
    Map.get state, :messages
  end
  defp addmessage state, message do
    update_in state.messages, fn messages -> [message | messages] end
  end

  def messages chat do
    Agent.get(chat, &getmessages/1)
  end

  def send chat, message do
    Agent.update(chat, &addmessage(&1, message))
  end
end

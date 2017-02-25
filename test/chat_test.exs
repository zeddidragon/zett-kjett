defmodule ZettKjett.ChatTest do
  use ExUnit.Case, async: true
  doctest ZettKjett.Chat
  alias ZettKjett.Chat

  test "contains a list of messages" do
    {:ok, chat} = Chat.start()
    assert [] = Chat.messages(chat)
    
    Chat.send(chat, "Hello")
    assert ["Hello"] = Chat.messages(chat)
  end
end

defmodule ZettKjett.Protocols.EchoTest do
  use ExUnit.Case, async: true 
  alias ZettKjett.Protocols.Echo
  alias ZettKjett.Models.{User, Chat, Message}

  setup do
    Echo.start_link self()
    :ok
  end

  test "me returns a user object" do
    assert %User{id: :me} = Echo.me
  end

  test "friends returns a list of chats" do
    assert [{%Chat{id: 1, user_id: :me}, %User{id: :me}}] = Echo.friends
  end

  test "sending/receiving of messages" do
    Echo.tell hd(Echo.friends), "Hello"
    assert_receive {:message, %Chat{}, %User{}, %Message{message: "Hello"}}
  end
end


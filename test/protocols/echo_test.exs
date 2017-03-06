defmodule ZettKjett.Protocols.EchoTest do
  use ExUnit.Case, async: true 
  alias ZettKjett.Protocols.Echo
  alias ZettKjett.Models.{User, Channel, Message}

  setup do
    Echo.start_link self()
    :ok
  end

  test "me returns a user object" do
    assert %User{id: :me} = Echo.me
  end

  test "friends returns a list of users" do
    assert [%User{id: :me}] = Echo.friends
  end

  test "chats returns a list of channels and associated users" do
    assert [{%Channel{id: 1}, [%User{id: :me}]}] = Echo.chats
  end

  test "sending/receiving of messages" do
    Echo.tell hd(Echo.friends), "Hello"
    assert_receive {:message, %Channel{}, %User{}, %Message{content: "Hello"}}
  end
end


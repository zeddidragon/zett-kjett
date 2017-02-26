defmodule ZettKjett.Protocols.EchoTest do
  use ExUnit.Case, async: true 
  alias ZettKjett.Protocols.Echo
  alias ZettKjett.Models.{User}

  setup do
    Echo.start_link self()
    :ok
  end

  test "me returns a user object" do
    assert %User{id: :me} = Echo.me
  end
end


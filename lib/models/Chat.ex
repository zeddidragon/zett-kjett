defmodule Chat do
  @enforce_keys [:id, :protocol, :user_id]
  defstruct [
    id: nil,
    user_id: nil,
    protocol: :unknown_protocol
  ]

  def start_link listener, messages // [] do
    Task.start_link fn -> loop(listener, messages) end
  end

  defp loop listener, messages do
    receive do
      {:put, message}->
        messages = Message.sort [message | messages]
        send listener, messages
        loop listener, messages
    end
  end
end

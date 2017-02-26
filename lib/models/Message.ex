defmodule Message do
  @enforce_keys [:id, :sender, :message, :sent_at]
  defstruct [
    id: nil,
    sender: nil,
    sent_at: nil,
    message: nil
  ]

  def sort messages do
    Enum.sort_by messages, fn m -> m.sent_at end
  end
end

defmodule ZettKjett.Models.Message do
  @enforce_keys [:id, :message, :sent_at]
  defstruct [
    id: nil,
    sent_at: nil,
    message: nil,
    edited_at: nil
  ]

  def sort messages do
    Enum.sort_by messages, fn m -> m.sent_at end
  end
end

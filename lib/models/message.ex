defmodule ZettKjett.Models.Message do
  @enforce_keys [:id, :user_id, :channel_id, :content, :sent_at]
  defstruct [
    id: nil,
    user_id: nil,
    channel_id: nil,
    content: nil,
    sent_at: nil,
    edited_at: nil
  ]

  def sort messages do
    Enum.sort_by messages, fn m -> m.sent_at end
  end
end

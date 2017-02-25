defmodule ZettKjett.Protocols.Discord do
  alias ZettKjett.Protocols.Discord.Rest

  def login user, pass do
    Rest.get 
  end
end

defmodule ZettKjett.Protocols.Discord.Rest do
  use HTTPotion.Base

  def process_url url do
    "https://discordapp.com/api/" <> url
  end
  
  def process_request_headers headers do
    Dict.put headers, :"User-Agent", "zettkjett-discord"
    Dict.put headers, :"Authorization", "zettkjett-discord-potion"
  end

  def process_response_body(body) do
    body
      |> IO.iodata_to_binary
      |> :jsx.decode
      |> Enum.map fn ({k, v}) -> { String.to_atom(k), v } end
      |> :orddict.from_list
  end
end

defmodule ZettKjett.Utils do
  alias IO.ANSI
  def inspect subject, options \\ [] do
    options = [
      pretty: true,
      syntax_colors: [
        number: ANSI.light_magenta,
        atom: ANSI.light_magenta,
        tuple: ANSI.light_yellow,
        map: ANSI.light_yellow,
        list: ANSI.light_green,
      ]
    ] ++ options
    IO.write "\e[s\e[0;25"
    IO.inspect subject, options
    IO.write "\e[u"
    subject
  end

  def parse_int str do
    str |> String.trim |> String.to_integer
  end

  def pad list, intended_length do 
    n = length list
    if n < intended_length do
      Enum.concat list, fill (n + 1)..intended_length
    else
      list
    end
  end

  def fill range, value \\ nil do
    Enum.map range, fn v -> value end
  end
end

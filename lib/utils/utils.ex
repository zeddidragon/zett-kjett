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
    IO.inspect subject, options
    subject
  end

  def parse_int str do
    str |> String.trim |> String.to_integer
  end

  def pad_leading list, intended_length, value \\ nil do 
    n = length list
    if n < intended_length do
      Enum.concat fill((n + 1)..intended_length, value), list
    else
      list
    end
  end

  def pad_trailing list, intended_length, value \\ nil do 
    n = length list
    if n < intended_length do
      Enum.concat list, fill((n + 1)..intended_length, value)
    else
      list
    end
  end

  def fill range, value \\ nil do
    Enum.map range, fn _ -> value end
  end

  defp pad num do
    String.pad_leading to_string(num), 2, "0"
  end

  def format_date {year, month, date} do
    [year, month, date]
      |> Enum.map(&pad/1)
      |> Enum.join("-")
  end

  def format_time {hour, minute, _} do
    [hour, minute]
      |> Enum.map(&pad/1)
      |> Enum.join(":")
  end

  def format_timestamp {monotonic, _, offset} do
    system_time = monotonic + offset
    seconds = :erlang.convert_time_unit(system_time, :native, :seconds)
    unit = {div(seconds, 1_000_000), rem(seconds, 1_000_000), 0}
    {date, time} = :calendar.now_to_local_time(unit)
    "#{format_date(date)} #{format_time(time)}"
  end

  def time_diff {mono1, _, _}, {mono2, _, _} do
    :erlang.convert_time_unit(abs(mono2 - mono1), :native, :seconds)
  end
  
  def now do
    { :erlang.monotonic_time,
      :erlang.unique_integer([:monotonic]),
      :erlang.time_offset }
  end

  def index(str, substr, n \\ 1) do
    matches = String.split(str, substr, parts: 1 + n)
    if length(matches) < 1 + n do
      {:error, :not_found}
    else
      index = matches
        |> Enum.slice(0..-2)
        |> Enum.map(&String.length/1)
        |> Enum.sum()
        |> Kernel.+(n * String.length(substr))
      {:ok, index}
    end
  end
end

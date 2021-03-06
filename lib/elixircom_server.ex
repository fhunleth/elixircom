defmodule Elixircom.Server do
  use GenServer

  alias Nerves.UART

  defmodule State do
    defstruct group_leader: nil, uart: nil, serial_port_name: nil, on_exit: nil
  end

  def start(opts) do
    GenServer.start(__MODULE__, opts)
  end

  def handle_input(server, char) do
    GenServer.cast(server, {:input, char})
  end

  def init(opts) do
    uart_opts = Keyword.get(opts, :uart_opts)
    serial_port_name = Keyword.get(opts, :serial_port_name)

    with {:ok, uart} <- UART.start_link(),
         :ok <- UART.open(uart, serial_port_name, uart_opts),
         opts = Keyword.put(opts, :uart, uart)
    do
      {:ok, struct(State, opts)}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_cast({:input, 2}, %State{uart: uart} = state) do
    Nerves.UART.close(uart)
    {:stop, :normal, state}
  end

  def handle_cast({:input, char}, %State{uart: uart} = state) do
    Nerves.UART.write(uart, key_to_uart(char))
    {:noreply, state}
  end

  def handle_info({:nerves_uart, _name, data}, %State{group_leader: gl} = state) do
    data = uart_to_printable(data)
    IO.write(gl, "#{data}")
    {:noreply, state}
  end

  defp uart_to_printable(data) do
    for <<c <- data>>, is_printable(c), into: "", do: <<c>>
  end

  defp is_printable(?\r), do: false
  defp is_printable(?\b), do: false
  defp is_printable(key) when key > 128, do: false
  defp is_printable(_), do: true

  defp key_to_uart(10), do: <<?\r, ?\n>>
  defp key_to_uart(127), do: <<?\b>>
  defp key_to_uart(key), do: <<key>>
end

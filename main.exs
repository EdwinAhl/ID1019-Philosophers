# 1 #############################################################
defmodule Chopstick do

  # START of chopstick
  def start do
    _stick = spawn_link(fn -> available() end)
  end

  # REQUEST stick to use
  def request(stick) do
    send(stick, {:request, self()})
    receive do
      :granted -> :ok
    end
  end
  def request(stick, timeout) do
    send(stick, {:request, self()})
    receive do
      :granted -> :ok
    after timeout ->
      :no
    end
  end
  def request(left, right, timeout) do
    send(left, {:request, self(), timeout})
    send(right, {:request, self(), timeout})
    receive do
      :granted ->
        receive do
          :granted ->
            send(left, :gone)
            send(right, :gone)
            :ok
          :expired -> :no
        end
      :expired -> :no
    end
  end

  # RETURN stick
  def return(stick) do
    send(stick, :return)
  end

  # QUIT stick process
  def quit(stick) do
    send(stick, :quit)
  end

  # AVAILABLE to use
  defp available() do
    receive do
     {:request, from} ->
       send(from, :granted)
       gone()
     :quit -> :ok
    end
  end
  defp available() do
    receive do
     {:request, from, timeout} ->
       send(from, :granted)
       granted(from, timeout)
     :quit -> :ok
    end
  end

  # GRANTED access to chopstick
  defp granted(from, timeout) do
    receive do
     :return ->
       available()
     :gone ->
       gone()
     :quit -> :ok
    after timeout ->
      send(from, :expired)
    end
  end

  # GONE from available
  defp gone() do
   receive do
    :return -> available()
    :quit -> :ok
   end
  end
end


# 2 #############################################################
defmodule Philosopher do

  @dream 800
  @eat 100
  @delay 800
  @timeout 800

  # START of philosopher
  def start(hunger, left, right, name, ctrl) do
    spawn_link(fn -> dreaming(hunger, left, right, name, ctrl) end)
  end

  # SLEEP
  def sleep(0) do :ok end
  def sleep(t) do
    :timer.sleep(:rand.uniform(t))
  end

  # DREAMING
  defp dreaming(0, _left, _right, name, ctrl) do
    IO.puts("#{name} is done")
    send(ctrl, :done)
  end
  defp dreaming(hunger, left, right, name, ctrl) do
    IO.puts("#{name} is dreaming")
    sleep(@dream)
    IO.puts("#{name} woke up")
    waiting(hunger, left, right, name, ctrl)
  end

  # WAITING for chopsticks
  defp waiting(hunger, left, right, name, ctrl) do
    IO.puts("#{name} is waiting")
    case Chopstick.request(left, @timeout) do
      :ok ->
        IO.puts("#{name} recieved left")
        sleep(@delay)
        case Chopstick.request(right, @timeout) do
          :ok ->
            IO.puts("#{name} recieved right")
            eating(hunger, left, right, name, ctrl)
          :no ->
            Chopstick.return(left)
            Chopstick.return(right)
            IO.puts("#{name} aborted right")
            dreaming(hunger, left, right, name, ctrl)
        end
      :no ->
        Chopstick.return(left)
        IO.puts("#{name} aborted left")
        dreaming(hunger, left, right, name, ctrl)
    end
  end

  # EATING with chopsticks
  defp eating(hunger, left, right, name, ctrl) do
    IO.puts("#{name} is eating")
    sleep(@eat)
    Chopstick.return(left)
    Chopstick.return(right)
    dreaming(hunger-1, left, right, name, ctrl)
  end

end


# 3 #############################################################
defmodule Dinner do

  # START
  def start(n), do: spawn(fn -> init(n) end)

  # INIT
  defp init(n) do
    c1 = Chopstick.start()
    c2 = Chopstick.start()
    c3 = Chopstick.start()
    c4 = Chopstick.start()
    c5 = Chopstick.start()
    ctrl = self()
    Philosopher.start(n, c1, c2, "Arendt", ctrl)
    Philosopher.start(n, c2, c3, "Hypatia", ctrl)
    Philosopher.start(n, c3, c4, "Simone", ctrl)
    Philosopher.start(n, c4, c5, "Elisabeth", ctrl)
    Philosopher.start(n, c5, c1, "Ayn", ctrl)
    wait(n, [c1, c2, c3, c4, c5])
  end

  # WAIT
  defp wait(0, chopsticks) do
    Enum.each(chopsticks, fn(c) -> Chopstick.quit(c) end)
  end
  defp wait(n, chopsticks) do
    receive do
      :done ->
        wait(n - 1, chopsticks)
      :abort ->
        Process.exit(self(), :kill)
    end
  end
end

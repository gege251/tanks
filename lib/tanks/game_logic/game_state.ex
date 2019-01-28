defmodule Tanks.GameLogic.GameState do
  use GenServer

  alias Tanks.GameLogic.GameState
  alias Tanks.GameLogic.Tank
  alias Tanks.GameLogic.Bullet

  @tick_rate 30

  defstruct tanks: Map.new(),
            bullets: []

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  @doc """
  Creates a tank

  ## Example

      iex> {:ok, pid} = Tanks.GameLogic.GameState.create_tank("test")
      iex> is_pid(pid)
      true

  """
  def create_tank(tank_id) do
    GenServer.call(__MODULE__, {:create_tank, tank_id})
  end

  @doc """
  Removes a tank and stops its process

    ## Example

    iex> Tanks.GameLogic.GameState.remove_tank("test")
    :error

    iex> Tanks.GameLogic.GameState.create_tank("test")
    iex> Tanks.GameLogic.GameState.remove_tank("test")
    :ok

  """
  def remove_tank(tank_id) do
    GenServer.call(__MODULE__, {:remove_tank, tank_id})
  end

  @doc """
  Get all tanks

  ## Example

      iex> Tanks.GameLogic.GameState.get_state()
      %{tanks: [], bullets: []}

      iex> Tanks.GameLogic.GameState.create_tank("test")
      iex> Tanks.GameLogic.GameState.get_state()
      %{tanks: [%Tanks.GameLogic.Tank{}], bullets: []}

  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Get PID by tankId

    ## Examples

    iex> Tanks.GameLogic.GameState.get_pid("test")
    :error

    iex> Tanks.GameLogic.GameState.create_tank("test")
    iex> {:ok, pid} = Tanks.GameLogic.GameState.get_pid("test")
    iex> is_pid(pid)
    true

  """
  def get_pid(tank_id) do
    GenServer.call(__MODULE__, {:get_pid, tank_id})
  end

  @doc """
  Fires a bullet from the specified tank

    ## Example

    iex> Tanks.GameLogic.GameState.create_tank("test")
    iex> Tanks.GameLogic.GameState.fire("test")
    iex> Tanks.GameLogic.GameState.get_state().bullets
    [%Bullet{x: 70, y: 574, velocity_x: 8, velocity_y: 0}]

  """
  def fire(tank_id) do
    GenServer.cast(__MODULE__, {:fire, tank_id})
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_rate)
  end

  ##########
  # SERVER #
  ##########

  def init(:ok) do
    schedule_tick()
    {:ok, %GameState{}}
  end

  # Evaluate movement
  def handle_info(:tick, state) do
    tank_pids = state.tanks |> Map.values()

    tank_pids |> Enum.map(&Tank.eval(&1))

    bullets =
      state.bullets
      |> Enum.reduce([], fn bullet, acc ->
        case Bullet.move(bullet) do
          {:ok, nextBullet} -> [nextBullet | acc]
          :error -> acc
        end
      end)

    remaining_bullets = GameState.get_hits(tank_pids, bullets)

    schedule_tick()
    {:noreply, %GameState{state | bullets: remaining_bullets}}
  end

  # Handle stopped processes
  def handle_info({:DOWN, _ref, :process, old_pid, _reason}, state) do
    tanks =
      for {k, pid} <- state.tanks, into: %{} do
        if pid == old_pid do
          {:ok, new_pid} = Tanks.GameLogic.TankSupervisor.add_tank()
          {k, new_pid}
        else
          {k, pid}
        end
      end

    {:noreply, %GameState{tanks: tanks}}
  end

  # Create a new tank
  def handle_call({:create_tank, tank_id}, _from, state) do
    if !Map.has_key?(state.tanks, tank_id) do
      {:ok, tank_pid} = Tanks.GameLogic.TankSupervisor.add_tank()
      Process.monitor(tank_pid)

      newState = %GameState{state | tanks: state.tanks |> Map.put_new(tank_id, tank_pid)}
      {:reply, {:ok, tank_pid}, newState}
    else
      {:reply, {:error, "Already existing"}, state}
    end
  end

  # Remove tank
  def handle_call({:remove_tank, tank_id}, _from, state) do
    if Map.has_key?(state.tanks, tank_id) do
      tank_pid = Map.fetch!(state.tanks, tank_id)
      tanks = Map.delete(state.tanks, tank_id)
      Tanks.GameLogic.TankSupervisor.remove_tank(tank_pid)
      {:reply, :ok, %GameState{state | tanks: tanks}}
    else
      {:reply, :error, state}
    end
  end

  # Get all tanks
  def handle_call(:get_state, _from, state) do
    tanks =
      state.tanks
      |> Map.values()
      |> Enum.map(&Tank.get_state(&1))

    {:reply, %{tanks: tanks, bullets: state.bullets}, state}
  end

  # Get tank PID
  def handle_call({:get_pid, tank_id}, _from, state) do
    {:reply, state.tanks |> Map.fetch(tank_id), state}
  end

  # Fire a bullet
  def handle_cast({:fire, tank_id}, state) do
    case Map.fetch(state.tanks, tank_id) do
      {:ok, tank_pid} ->
        case Tank.fire(tank_pid) do
          {:ok, bullet} -> {:noreply, %GameState{state | bullets: [bullet | state.bullets]}}
          :error -> {:noreply, state}
        end

      :error ->
        {:noreply, state}
    end
  end

  def to_api(%{tanks: tanks, bullets: bullets}) do
    %{
      tanks: tanks |> Enum.map(&Tank.to_api(&1)),
      bullets: bullets |> Enum.map(&Bullet.to_api(&1))
    }
  end

  def get_hits(tank_pids, bullets) do
    hit_bullets =
      for tank_pid <- tank_pids, bullet <- bullets do
        tank = Tank.get_state(tank_pid)

        if Tanks.GameLogic.Field.colliding?(tank, bullet) do
          Tank.injure(tank_pid, 20)
          bullet
        end
      end

    bullets
    |> Enum.filter(fn bullet ->
      Enum.all?(hit_bullets, fn hit_bullet -> hit_bullet != bullet end)
    end)
  end
end
defmodule Tanks.GameLogic.Tank do
  use GenServer, restart: :temporary

  alias Tanks.GameLogic.Tank
  alias Tanks.GameLogic.Bullet
  alias Tanks.GameLogic.Field

  @max_velocity 5
  @max_turret_angle_velocity 0.03
  @max_turret_angle 0.5
  @min_turret_angle -0.2
  @bullet_velocity 8
  @loading_speed 1

  defstruct player_name: "",
            alive_ticks: 0,
            health: 100,
            width: 60,
            height: 40,
            x: 0,
            y: 560,
            load: 100,
            velocity_x: 0,
            velocity_y: 0,
            direction: :right,
            turret_angle: 0.0,
            turret_angle_velocity: 0.0

  def start_link({player_name, seed}) do
    GenServer.start_link(__MODULE__, {:ok, player_name, seed}, [])
  end

  @doc """
  Get current state of a tank

    ## Example

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.get_state(pid)
    %Tanks.GameLogic.Tank{x: 16, player_name: "test"}

  """
  def get_state(tankPid) do
    GenServer.call(tankPid, :get_state)
  end

  @doc """
  Validate and set velocity

    ## Example

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.set_movement(pid, -10)
    iex> Tanks.GameLogic.Tank.get_state(pid)
    %Tanks.GameLogic.Tank{x: 16, velocity_x: -5, player_name: "test"}

  """
  def set_movement(tankPid, velocity) do
    GenServer.cast(tankPid, {:set_movement, velocity})
  end

  @doc """
  Validate and set turret angle

    ## Examples

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.set_turret_angle_velocity(pid, 0.01)
    iex> Tanks.GameLogic.Tank.get_state(pid)
    %Tanks.GameLogic.Tank{x: 16, player_name: "test", turret_angle_velocity: 0.01}

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.set_turret_angle_velocity(pid, -0.7)
    iex> Tanks.GameLogic.Tank.get_state(pid)
    %Tanks.GameLogic.Tank{x: 16, player_name: "test", turret_angle_velocity: -0.03}

  """
  def set_turret_angle_velocity(tankPid, angle) do
    GenServer.cast(tankPid, {:set_turret_angle_velocity, angle})
  end

  @doc """
  Evaluate the movement of a tank

    ## Example

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.set_movement(pid, 10)
    iex> Tanks.GameLogic.Tank.set_turret_angle_velocity(pid, 0.03)
    iex> Tanks.GameLogic.Tank.fire(pid)
    iex> Tanks.GameLogic.Tank.eval(pid)
    iex> Tanks.GameLogic.Tank.get_state(pid)
    %Tanks.GameLogic.Tank{player_name: "test", velocity_x: 5, turret_angle_velocity: 0.03, x: 21, turret_angle: 0.03, load: 1, alive_ticks: 1}

  """
  def eval(tankPid) do
    GenServer.cast(tankPid, :eval)
  end

  @doc """
  Fire a bullet

    ## Example

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.fire(pid)
    {:ok, %Bullet{x: 86, y: 574, velocity_x: 8, velocity_y: 0}}

  """
  def fire(tankPid) do
    GenServer.call(tankPid, :fire)
  end

  @doc """
  Injure hits

    iex> {:ok, pid} = Tanks.GameLogic.Tank.start_link({ "test", 0 })
    iex> Tanks.GameLogic.Tank.injure(pid, 10)
    iex> Tanks.GameLogic.Tank.get_state(pid)
    %Tanks.GameLogic.Tank{x: 16, player_name: "test", health: 90}
  """
  def injure(tankPid, health_penalty) do
    GenServer.cast(tankPid, {:injure, health_penalty})
  end

  ##########
  # SERVER #
  ##########

  def init({:ok, player_name, seed}) do
    {:ok, %Tank{player_name: player_name} |> Field.randomize_position(seed)}
  end

  def handle_cast({:set_movement, velocity}, tank) do
    velocity_x = velocity |> min(@max_velocity) |> max(-@max_velocity)
    newTank = %Tank{tank | velocity_x: velocity_x}

    {:noreply, newTank}
  end

  def handle_cast(:eval, tank) do
    if tank.health > 0 do
      new_tank =
        case Field.move_object(tank) do
          {:ok, moved_tank} -> moved_tank
          :error -> tank
        end
        |> switch_direction()
        |> move_turret()
        |> load_bullet()
        |> increment_alive_ticks()

      {:noreply, new_tank}
    else
      {:noreply, tank}
    end
  end

  def handle_cast({:set_turret_angle_velocity, angle}, tank) do
    newAngle =
      angle
      |> min(@max_turret_angle_velocity)
      |> max(-@max_turret_angle_velocity)

    {:noreply, %Tank{tank | turret_angle_velocity: newAngle}}
  end

  def handle_cast({:injure, health_penalty}, tank) do
    {:noreply, %Tank{tank | health: (tank.health - health_penalty) |> max(0)}}
  end

  def handle_call(:get_state, _from, tank) do
    {:reply, tank, tank}
  end

  def handle_call(:fire, _from, tank) do
    if tank.load < 100 or tank.health <= 0 do
      {:reply, :error, tank}
    else
      bullet =
        case tank.direction do
          :left ->
            %Bullet{
              x: tank.x + 20 - round(20 * :math.cos(tank.turret_angle)),
              y: tank.y + 14 - round(20 * :math.sin(tank.turret_angle)),
              velocity_x: round(-@bullet_velocity * :math.cos(tank.turret_angle)),
              velocity_y: round(-@bullet_velocity * :math.sin(tank.turret_angle))
            }

          :right ->
            %Bullet{
              x: tank.x + 50 + round(20 * :math.cos(tank.turret_angle)),
              y: tank.y + 14 - round(20 * :math.sin(tank.turret_angle)),
              velocity_x: round(@bullet_velocity * :math.cos(tank.turret_angle)),
              velocity_y: round(-@bullet_velocity * :math.sin(tank.turret_angle))
            }
        end

      {:reply, {:ok, bullet}, %Tank{tank | load: 0}}
    end
  end

  defp move_turret(tank) do
    %Tank{
      tank
      | turret_angle:
          (tank.turret_angle + tank.turret_angle_velocity)
          |> min(@max_turret_angle)
          |> max(@min_turret_angle)
    }
  end

  defp load_bullet(tank) do
    %Tank{
      tank
      | load: (tank.load + @loading_speed) |> min(100)
    }
  end

  defp switch_direction(tank) do
    %Tank{
      tank
      | direction:
          cond do
            tank.velocity_x < 0 -> :left
            tank.velocity_x > 0 -> :right
            tank.velocity_x == 0 -> tank.direction
          end
    }
  end

  defp increment_alive_ticks(tank) do
    %Tank{tank | alive_ticks: tank.alive_ticks + 1}
  end

  defmodule Broadcast do
    alias Tanks.GameLogic.Tank

    @derive Jason.Encoder
    @enforce_keys [:player_name, :alive_time, :health, :x, :y, :load, :direction, :turret_angle]
    defstruct [:player_name, :alive_time, :health, :x, :y, :load, :direction, :turret_angle]

    @doc """
    Creates a broadcast ready object

      # Example

      iex> tank = %Tanks.GameLogic.Tank{}
      iex> Tanks.GameLogic.Tank.Broadcast.from_tank(tank)
      %Tanks.GameLogic.Tank.Broadcast{player_name: "", x: 0, y: 560, health: 100, turret_angle: 0.0, load: 100, direction: :right, alive_time: 0}

    """
    def from_tank(tank = %Tank{}) do
      %Tank.Broadcast{
        player_name: tank.player_name,
        x: round(tank.x),
        y: round(tank.y),
        health: tank.health,
        turret_angle: tank.turret_angle,
        load: tank.load,
        direction: tank.direction,
        alive_time: tank.alive_ticks |> Tanks.GameLogic.Battle.ticks_to_seconds()
      }
    end
  end
end

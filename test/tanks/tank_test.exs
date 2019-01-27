defmodule TankTest do
  use ExUnit.Case
  doctest Tank
  doctest Bullet

  test "Firing with different turret angles" do
    {:ok, pid} = Tank.start_link([])
    bullet1 = Tank.fire(pid)

    Tank.set_turret_angle_velocity(pid, 0.04)
    for n <- 0..10, do: Tank.eval(pid)
    bullet2 = Tank.fire(pid)

    assert bullet1.y !== bullet2.y
    assert bullet1.velocity_y !== bullet2.velocity_y
  end
end

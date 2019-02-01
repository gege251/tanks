defmodule Tanks.BattleLodge do
  use GenServer

  alias Tanks.BattleSupervisor

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  @doc """
  Start a battle server

  ## Example

    iex> Tanks.BattleLodge.start_battle("test")
    :ok

    iex> Tanks.BattleLodge.start_battle("test")
    iex> Tanks.BattleLodge.start_battle("test")
    :error

  """
  def start_battle(name) when is_binary(name) do
    GenServer.call(__MODULE__, {:start_battle, name})
  end

  @doc """
  Close a battle server

  ## Example

    iex> Tanks.BattleLodge.start_battle("test")
    iex> Tanks.BattleLodge.close_battle("test")
    iex> Tanks.BattleLodge.list_battles() |> length
    0

  """
  def close_battle(name) when is_binary(name) do
    GenServer.cast(__MODULE__, {:close_battle, name})
  end

  @doc """
  Close a battle server

  ## Example

    iex> Tanks.BattleLodge.start_battle("test")
    iex> [{"test", pid}] = Tanks.BattleLodge.list_battles()
    iex> is_pid(pid)
    true


  """
  def list_battles do
    GenServer.call(__MODULE__, :list_battles)
  end

  def init(:ok) do
    :ets.new(:battles, [:named_table])
    {:ok, Map.new()}
  end

  def handle_call({:start_battle, name}, _from, state) do
    {:ok, pid} = BattleSupervisor.start_battle()
    success = :ets.insert_new(:battles, {name, pid})

    if success do
      {:reply, :ok, state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call(:list_battles, _from, state) do
    list = :ets.tab2list(:battles)
    {:reply, list, state}
  end

  def handle_cast({:close_battle, name}, state) do
    [{^name, battle_pid}] = :ets.lookup(:battles, name)
    :ets.delete(:battles, name)
    BattleSupervisor.close_battle(battle_pid)

    {:noreply, state}
  end
end

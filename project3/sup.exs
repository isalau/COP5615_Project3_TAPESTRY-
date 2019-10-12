defmodule SUP do
  use DynamicSupervisor

  def start_link(init_arg) do
    IO.puts("Its here in DynamicSupervisor")
    {:ok, _pid} = DynamicSupervisor.start_link(__MODULE__, init_arg, name: DynamicSupervisor)
  end

  def start_child(x,nl) do
    child_spec = Supervisor.child_spec({Node, [x,nl]}, id: x, restart: :temporary)
    {:ok, child} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

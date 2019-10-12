defmodule NODE do
  use GenServer

  def start_link([init_arg, nl]) do
    id = init_arg
    new_arg = 0
    # Check - if this works
    {:ok, _pid} = GenServer.start_link(__MODULE__, {new_arg, nl}, name: :"#{id}")
  end

  def init({init_arg, nl}) do
    {:ok, {init_arg, nl}}
  end

end

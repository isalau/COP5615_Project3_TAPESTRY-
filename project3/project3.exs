defmodule MAINPROJ do
  @moduledoc """
  Documentation for PROJECT3.
  """

  @doc """
  Hello world.

  ## Examples

      iex> PROJECT3.hello()
      :world

  """
  def main(numNodes,_numRequests) do
    ################# STARTS SUPERVISOR ######################
    # # number of Nodes
    # numNodes = String.to_integer(Enum.at(argv, 0))
    #
    # # number of Requests
    # numRequests = String.to_integer(Enum.at(argv, 1))

    # Range of GenServers
    rng = Range.new(1, numNodes)

    # Starting the dynamic Server
    {:ok, _pid} = DySupervisor.start_link(1)

    ################# CREATES NUMBER OF NODES ######################

    ################# ADDS NODES TO TAPESTRY ######################
    ################# ADSS NODES TO SUPERVISOR ######################
    for x <- rng do
      nl = []
      IO.puts("Child #{x} starting")
      DySupervisor.start_child(x, nl)
      IO.puts("Child #{x} started")
    end

    ################# START ALL NODES ######################
  end
end

defmodule DySupervisor do
  use DynamicSupervisor

  def start_link(index) do
    IO.puts("Its #{index} here in DynamicSupervisor")
    {:ok, _pid} = DynamicSupervisor.start_link(__MODULE__, index, name: __MODULE__)
  end

  def start_child(index,neighbor_map) do
    IO.puts("DynamicSupervisor adding #{index} child")
    child_spec = Supervisor.child_spec({TAPNODE, [index,neighbor_map]}, id: index, restart: :temporary)
    {:ok, _child} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(_index) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule TAPNODE do
  use GenServer

  def start_link([index, neighbor_map]) do
    IO.puts("Its #{index} here in TAPNODE")
    {:ok, _pid} = GenServer.start_link(__MODULE__, {index, neighbor_map}, name: :"#{index}")
  end

  def init({index, neighbor_map}) do
    {:ok, {index, neighbor_map}}
  end

end


#Take command line arguments
arguments = System.argv()

#Make them into integers
numNodes = String.to_integer(Enum.at(arguments,0))
numRequests = String.to_integer(Enum.at(arguments,1))

#Pass the integers to Actor 1
MAINPROJ.main(numNodes, numRequests)

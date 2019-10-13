defmodule MAINPROJ do
  def main(numNodes, numRequests) do
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
      neighbor_map = []
      neighbor_map = Full_topology.full_topology(x, rng)
      IO.puts("Child #{x} starting")
      DySupervisor.start_child(x, numRequests, neighbor_map)
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

  def start_child(index,numRequests,neighbor_map) do
    IO.puts("DynamicSupervisor adding #{index} child")
    child_spec = Supervisor.child_spec({TAPNODE, [index,numRequests,neighbor_map]}, id: index, restart: :temporary)
    {:ok, _child} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(_index) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule TAPNODE do
  use GenServer

  def start_link([index, numRequests,neighbor_map]) do
    IO.inspect(neighbor_map, label: "Its #{index} here in TAPNODE with #{numRequests} requests and neighbor map")
    {:ok, _pid} = GenServer.start_link(__MODULE__, {index, numRequests,neighbor_map}, name: :"#{index}")
  end

  def init({index, numRequests,neighbor_map}) do
    #call sendRequestFunction
    serverTo = Enum.at(neighbor_map, 0)
    serverFrom = self()
    msg = "testMsg"

    TAPNODE.sendMessageFunction(serverTo,serverFrom, msg)
    {:ok, {index, numRequests,neighbor_map}}
  end
  # Server
  @impl true
  def handle_call({:receiveMsg}, _from, {serverFrom, msg}) do
    IO.inspect(serverFrom, label: "in server receiveMsg")

    {:reply, :ok, {serverFrom, msg}}
  end
  # CLient
  def sendMessageFunction(serverTo,serverFrom, msg) do
    IO.inspect(serverTo, label: "in client sendMessageFunction serverTo" )
    GenServer.call(serverTo, {:receiveMsg, {serverFrom, msg}})
  end

end

defmodule Full_topology do
  def full_topology(node_num, rng) do
    # Produce a list of neighbors for the given specific node
    main_node = node_num
    nebhrs = Enum.filter(rng, fn x -> x != main_node end)
    nl = Enum.map(nebhrs, fn x -> :"#{x}" end)
  end
end

#Take command line arguments
arguments = System.argv()

#Make them into integers
numNodes = String.to_integer(Enum.at(arguments,0))
numRequests = String.to_integer(Enum.at(arguments,1))

#Pass the integers to Actor 1
MAINPROJ.main(numNodes, numRequests)

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
    {:ok, _pid} = Tapestry.start_link(1)

    ################# CREATES NUMBER OF NODES ######################

    ################# ADDS NODES TO TAPESTRY ######################
    ################# ADSS NODES TO SUPERVISOR ######################
    for x <- rng do
      neighbor_map = []
      neighbor_map = Full_topology.full_topology(x, rng)
      IO.puts("Child #{x} starting")
      Tapestry.start_child(x, numRequests, neighbor_map)
      IO.puts("Child #{x} started")
    end

    ################# START ALL NODES ######################
  end
end

defmodule Tapestry do
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
    #Tapestry currently uses an identifier space of 160-bit values
    #Tapestry assumes nodeIDs and GUIDs are roughly evenly distributed in the namespace, which can be achieved by using a secure hashing algorithm like SHA-1
    random_number = :rand.uniform(10000)
    sha = :crypto.hash(:sha, "#{random_number}")
    nodeID = sha |> Base.encode16
    IO.inspect(nodeID, label: "sha 1 output")

    # find where you belong
    # A node N has a neighbor map with multiple levels, where each level contains links to nodes matching a prefix up to a digit position in the ID, and contains a number of entries equal to the ID’s base.
    # The primary ith entry in the jth level is the ID and location of the closest node that begins with prefix (N, j-1) + i

    # update your neighbor_map (& neighbors update theirs)
    IO.inspect(neighbor_map, label: "Its #{index} here in with sha1 TAPNODE with #{numRequests} requests and neighbor map")
    {:ok, _pid} = GenServer.start_link(__MODULE__, {index, numRequests,neighbor_map}, name: :"#{index}")
  end

  def init({index, numRequests,neighbor_map}) do
    #send a request to all your neighbors
    serverTo = Enum.at(neighbor_map, 0)
    serverFrom = self()
    msg = "testMsg"

    # TAPNODE.sendMessageFunction(serverTo,serverFrom, msg)
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

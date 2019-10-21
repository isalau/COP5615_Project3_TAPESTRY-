defmodule MAINPROJ do
  def main(numNodes, numRequests) do
    ################# STARTS SUPERVISOR ######################
    # # number of Nodes
    # numNodes = String.to_integer(Enum.at(argv, 0))
    #
    # # number of Requests
    # numRequests = String.to_integer(Enum.at(argv, 1))

    # Starting the dynamic Server
    {:ok, _pid} = TAPESTRY.start_link(1)

    ################# CREATES NUMBER OF NODES ######################
    # Range of GenServers
    rng = Range.new(1, numNodes)

    for x <- rng do
      TAPESTRY.start_child(x, numRequests)
      IO.puts("Child #{x} started")
    end

    ################# CREATE OVERLAY NETWORK  ######################
    children = DynamicSupervisor.which_children(DySupervisor)

    for x <- children do
      {_, childPid, _, _} = x
      TAPNODE.addToTapestry(childPid)
    end

    ################# SEND FIRST REQUEST FROM ALL NODES ######################
  end
end

defmodule TAPESTRY do
  use DynamicSupervisor

  def start_link(index) do
    IO.puts("Its #{index} here in DynamicSupervisor")
    {:ok, _pid} = DynamicSupervisor.start_link(__MODULE__, index, name: __MODULE__)
  end

  def start_child(index, numRequests) do
    IO.puts("DynamicSupervisor adding #{index} child")

    child_spec =
      Supervisor.child_spec({TAPNODE, [index, numRequests]},
        id: index,
        restart: :temporary
      )

    {:ok, _child} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(_index) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule TAPNODE do
  use GenServer

  def start_link([index, numRequests]) do
    # -	Node N requests a new ID new_id

    # Tapestry currently uses an identifier space of 160-bit values
    # Tapestry assumes nodeIDs and GUIDs are roughly evenly distributed in the namespace, which can be achieved by using a secure hashing algorithm like SHA-1
    random_number = :rand.uniform(10000)
    sha = :crypto.hash(:sha, "#{random_number}")
    new_id = sha |> Base.encode16()
    IO.inspect(new_id, label: "sha 1 output")
    numRequestToSend = numRequests
    # neighborMap = empty list
    # ROUTER = ??
    # DYNAMIC_NODE_MANAGEMENT == ?
    {:ok, _pid} = GenServer.start_link(__MODULE__, {index, new_id, numRequestToSend})
  end

  @impl true
  def init({index, new_id, numRequestToSend}) do
    {:ok, {index, new_id, numRequestToSend}}
  end

  # Server
  @impl true
  def handle_call({:receiveMsg}, _from, {serverFrom, msg}) do
    IO.inspect(serverFrom, label: "in server receiveMsg")

    {:reply, :ok, {serverFrom, msg}}
  end

  # CLient
  def sendMessageFunction(serverTo, serverFrom, msg) do
    IO.inspect(serverTo, label: "in client sendMessageFunction serverTo")
    GenServer.call(serverTo, {:receiveMsg, {serverFrom, msg}})
  end

  # Client
  def routeNode(pID, nodeID) do
    # A node N has a neighbor map with multiple levels, where each level contains links to nodes matching a prefix up to a digit position in the ID, and contains a number of entries equal to the ID’s base.
    # The primary ith entry in the jth level is the ID and location of the closest node that begins with prefix (N, j-1) + i
  end

  # Client
  def addToTapestry(childPid) do
    state = :sys.get_state(childPid)
    # state = index, new_id, numRequestToSend
    index = elem(state, 0)
    new_id = elem(state, 1)
    numRequestToSend = elem(state, 2)
    IO.inspect(new_id, label: "#{index}'s new_id is")
  end
end

# Take command line arguments
arguments = System.argv()

# Make them into integers
numNodes = String.to_integer(Enum.at(arguments, 0))
numRequests = String.to_integer(Enum.at(arguments, 1))

# Pass the integers to Actor 1
MAINPROJ.main(numNodes, numRequests)

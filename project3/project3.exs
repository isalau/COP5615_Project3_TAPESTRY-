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
    children = DynamicSupervisor.which_children(TAPESTRY)

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

  ################# SERVER ######################
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

  @impl true
  def handle_call({:receiveMsg}, _from, {serverFrom, msg}) do
    IO.inspect(serverFrom, label: "in server receiveMsg")

    {:reply, :ok, {serverFrom, msg}}
  end

  # Server
  @impl true
  def handle_cast({:receiveHello, n_id}, state) do
    # SendNeighborMap(new_neighbor, N)
    # “When we proceed to fill in an empty entry at N, we know from our algorithm the range of objects whose surrogate route were moved from”  [N+1 entry location]
    # “We can then explicitly delete those entries”
    # “republish those objects”
    # “establishing new surrogate routes which account for the new inserted node.”
    {:noreply, state}
  end

  # Server
  @impl true
  def handle_cast({:receiveNeighborMap, n_id, n_neighborMap}, state) do
  end

  ################# CLIENT ######################

  def stayAlive(keep) do
    if keep == true do
      stayAlive(true)
    end
  end

  def addToTapestry(childPid) do
    state = :sys.get_state(childPid)
    # state = index, new_id, numRequestToSend, neighborMap
    index = elem(state, 0)
    new_id = elem(state, 1)
    # numRequestToSend = elem(state, 2)
    IO.inspect(new_id, label: "#{index}'s new_id is")

    # OG = N as an object
    # Objects routed by ID
    gNode = contactGatewayNode(new_id, childPid)
    hNode = gNode
    # For (i=0; H != NULL; i++) {
    # Grab ith level NeighborMap_i from H;
    # For (j=0; j<baseofID; j++) {
    # //Fill in jth level of neighbor map
    # Call updateYourNeighborMap()
    # While (Dist(N, NM_i(j, neigh)) > min(eachDist(N, NM_i(j, sec.neigh)))) {
    # neigh=sec.neighbor;
    # sec.neighbors=neigh−>sec.neighbors(i,j);
    # }
    # }
    # H = NextHop(i+1, new_id);
    # } //terminate when null entry found
    # Route to current surrogate via new_id;
    # Move relevant pointers off current surrogate;
    # Call notifyNeighbors(surrogate(new_id))
  end

  # for initalizing I need to know at least one other node from supervisor
  # really only the first node should have to use this function?
  def contactGatewayNode(new_id, childPid) do
    children = DynamicSupervisor.which_children(TAPESTRY)
    # get a node from supervisor that is not yourself
    {_, newChildPid, _, _} = Enum.at(children, 1)

    if newChildPid != childPid do
    else
      {_, newChildPid, _, _} = Enum.at(children, 0)
    end

    # Call routeToObject (OG); Use routing algorithm to find G as if N was an object
    # Returns Node G
    nodeG = routeToObject(new_id)
  end

  def routeToObject(new_id) do
    # Return root node of where object is (or would be) located
    # Uses nextHop function?
  end

  def nextHop(n, G) do
    # if n = MaxHop(R) then
    #   return self
    # else
    #   d <- Gn
    #   e <- Rn,d
    #   while d <- d_ 1 (modB)
    #     e <-Rn,d
    #   endwhile
    #   if e - self then
    #     return NextHop(n+1, G)
    #   else
    #     return e
    #   endif
    # endif
  end

  def updateYourNeighborMap() do
    # For (i=0;i<digits && H(i) !=NULL;){
    # 1.	Send Hello(i) to H(i)
    # 2.	Send NeighborMap’(i)
    # 3.	NM(i) = Optimize N.M.’(i)
    # 4.	Hi + 1 = LookupNM(N, i+1)
    # 5.	H = Hi+1
    # }
  end

  def sendHello(neighbor_id, n_id) do
    # Node N sends hello to Neighbor new_neighbor  H(i)
    GenServer.cast(neighbor_id, {:receiveHello, n_id})
  end

  def sendNeighborMap(neighbor_id, n_pid) do
    # Neighbor new_neighbor sends its neighbor map to Node N
    state = :sys.get_state(n_pid)
    # state = index, new_id, numRequestToSend, neighborMap
    # n_neighborMap = elem(state, 3)
    n_neighborMap = []
    GenServer.cast(neighbor_id, {:receiveNeighborMap, n_pid, n_neighborMap})
  end

  def sendMessageFunction(serverTo, serverFrom, msg) do
    IO.inspect(serverTo, label: "in client sendMessageFunction serverTo")
    GenServer.call(serverTo, {:receiveMsg, {serverFrom, msg}})
  end

  def routeNode(N, Exact) do
    # A node N has a neighbor map with multiple levels, where each level contains links to nodes matching a prefix up to a digit position in the ID, and contains a number of entries equal to the ID’s base.
    # The primary ith entry in the jth level is the ID and location of the closest node that begins with prefix (N, j-1) + i
  end
end

# Take command line arguments
arguments = System.argv()

# Make them into integers
numNodes = String.to_integer(Enum.at(arguments, 0))
numRequests = String.to_integer(Enum.at(arguments, 1))

# Pass the integers to Actor 1
MAINPROJ.main(numNodes, numRequests)

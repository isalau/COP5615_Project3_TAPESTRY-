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
      state = :sys.get_state(childPid)
      new_id = elem(state, 1)
      IO.inspect(childPid, label: "childPid")
      # IO.inspect(new_id, label: "new_id")
      TAPNODE.addToTapestry(childPid)
    end

    # keepAlive()
    ################# SEND FIRST REQUEST FROM ALL NODES ######################
  end

  def keepAlive() do
    keepAlive()
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
    # IO.inspect(self(), label: "#{index}s pid")
    # Tapestry currently uses an identifier space of 160-bit values
    # Tapestry assumes nodeIDs and GUIDs are roughly evenly distributed in the namespace, which can be achieved by using a secure hashing algorithm like SHA-1
    random_number = :rand.uniform(10000)
    sha = :crypto.hash(:sha, "#{random_number}")
    new_id = sha |> Base.encode16()
    IO.inspect(new_id, label: "sha 1 output")

    numRequestToSend = numRequests

    neighborMap = [
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "j",
      "k",
      "l",
      "m",
      "n",
      "o",
      "p",
      "q",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
      "z",
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "j",
      "k",
      "l",
      "m",
      "n",
      "o",
      "p",
      "q",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
      "z"
    ]

    # ROUTER = ??
    # DYNAMIC_NODE_MANAGEMENT == ?
    {:ok, _pid} = GenServer.start_link(__MODULE__, {index, new_id, numRequestToSend, neighborMap})
  end

  @impl true
  def init({index, new_id, numRequestToSend, neighborMap}) do
    {:ok, {index, new_id, numRequestToSend, neighborMap}}
  end

  @impl true
  def handle_call({:receiveMsg}, _from, {serverFrom, msg}) do
    # IO.inspect(serverFrom, label: "in server receiveMsg")

    {:reply, :ok, {serverFrom, msg}}
  end

  # Server
  @impl true
  def handle_cast({:addToTapestry}, state) do
    # state = :sys.get_state(childPid)
    # state = index, new_id, numRequestToSend, neighborMap
    index = elem(state, 0)
    new_id = elem(state, 1)
    numRequestToSend = elem(state, 2)
    # neighborMap = elem(state, 3)
    # IO.inspect(new_id, label: "#{index}'s new_id is")

    # OG = N as an object; objects routed by ID

    gNode = contactGatewayNode(new_id, self())
    # IO.inspect(gNode, label: "GatewayNode'd ID is")

    hNode = gNode
    # i is the level; 41 levels because 40 digits in id ???
    # For (i=0; hNode != NULL; i++) {}
    # QUESTION: What should hNodeToRoute return?
    hNodeToRoute(hNode, 0, new_id)
    # Route to current surrogate via new_id;
    # Move relevant pointers off current surrogate;
    # Use surrogate(new_id) backptrs to notify nodes by flooding back levels to where surrogate routing first became necessary
    routeToCurrentSurrogate(hNode)
    {:noreply, state}
  end

  # Server
  @impl true
  def handle_cast({:receiveHello, n_id, neighbor_id}, state) do
    # IO.puts("Received Hello from #{neighbor_id}")
    new_state = placeInNeighborMap(n_id, state, neighbor_id)

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
    GenServer.cast(childPid, {:addToTapestry})
  end

  def contactGatewayNode(new_id, childPid) do
    children = DynamicSupervisor.which_children(TAPESTRY)
    # get a node from supervisor that is not yourself--> surrogate root
    {_, neighbor_id, _, _} = Enum.at(children, 1)

    if neighbor_id != childPid do
      # Returns Node G id
      nodeG = neighbor_id
    else
      {_, neighbor_id, _, _} = Enum.at(children, 0)

      # Returns Node G state
      nodeG = neighbor_id
    end
  end

  # stopping condition --> last level
  def hNodeToRoute(hNode, i, new_id) when i == 40 do
    # copy everything but recursion from below
  end

  def hNodeToRoute(hNode, i, new_id) do
    # Send Hello to neighbor no matter what so they can check if they need to add me to their map
    # QUESTION: Can I send direct hello?
    TAPNODE.sendHello(hNode, self(), new_id)

    # state = :sys.get_state(hNode)
    # index = elem(state, 0)
    # new_id = elem(state, 1)
    # neighbor_map = elem(state, 3)
    # # Grab ith level NeighborMap_i from H;
    # # check if that level is empty --> terminate when null entry found
    # i_level_neighbor_map = Enum.at(neighbor_map, i)
    #
    # if i_level_neighbor_map != nil do
    #   IO.puts("ith level NeighborMap_i from H: #{i_level_neighbor_map}")
    #
    #   # The new node stops copying neighbor maps when a neighbor map lookup shows an empty entry in the next hop.
    #   # For (j=0; j<baseOfID; j++) {}
    #   baseOfIDLoop(0)
    #   new_i = i + 1
    #   hNodeToRoute(hNode, new_i)
    # end
  end

  # stopping condition --> last level
  def baseOfIDLoop(j) when j == 40 do
    # Fill in jth level of MY neighbor map
    # updateYourNeighborMap()
    # While (Dist(N, NM_i(j, neigh)) > min(eachDist(N, NM_i(j, sec.neigh)))) {}
    # dist()
    # H = NextHop(i+1, new_id);
  end

  def baseOfIDLoop(j) do
    # Fill in jth level of MY neighbor map
    # updateYourNeighborMap()
    # While (Dist(N, NM_i(j, neigh)) > min(eachDist(N, NM_i(j, sec.neigh)))) {}
    # dist()
    # H = NextHop(i+1, new_id);
    # new_j = j + 1
    # baseOfIDLoop(new_j)
  end

  def dist() do
    # neigh=sec.neighbor;
    # sec.neighbors=neigh−>sec.neighbors(i,j);
  end

  def routeToCurrentSurrogate(surrogate_Node) do
    # routes to the current surrogate for new_id, and moves data meant for new_id to N
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

  def sendHello(neighbor_id, n_id, new_id) do
    # Node N sends hello to Neighbor new_neighbor  H(i)
    GenServer.cast(neighbor_id, {:receiveHello, n_id, new_id})
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

  def placeInNeighborMap(neighbor_pid, my_state, neighbor_id) do
    IO.inspect(neighbor_id, label: "neighbor_id")

    my_id = elem(my_state, 1)
    IO.inspect(my_id, label: "my_id")

    my_neighborMap = elem(my_state, 3)

    # find j - compare characters to find what level it belongs to
    j = findJ(my_id, neighbor_id, 0)

    if j > 0 do
      j_corrected = j - 1
      IO.puts("Length of most in common prefix #{j_corrected}")

      prefix = String.slice(my_id, 0..j_corrected)
      IO.puts("Common prefix between #{my_id} and #{neighbor_id} is #{prefix}")
      # find i
      i_index = j_corrected + 1
      i = String.at(neighbor_id, i_index)
      IO.puts("i for #{neighbor_id} is: #{i}")
    else
      # i is the first elemment
      i = String.at(neighbor_id, 0)
      IO.puts("i for #{neighbor_id} is: #{i}")
    end

    # Notified nodes have the option of measuring distance to N, and if appropriate, replacing an existing neighbor entry with N.
    # As nodes receive the message, they add N to their routing tables and transfer references of locally rooted pointers as necessary
    # “When we proceed to fill in an empty entry at N, we know from our algorithm the range of objects whose surrogate route were moved from”  [N+1 entry location]
    # “We can then explicitly delete those entries”
    # “republish those objects”
    # “establishing new surrogate routes which account for the new inserted node.”
    # SendNeighborMap(new_neighbor, N)
    my_state
  end

  def findJ(my_id, neighbor_id, j) do
    prefixA = String.slice(my_id, 0..j)
    prefixB = String.slice(neighbor_id, 0..j)
    new_j = j + 1

    if prefixA == prefixB do
      # IO.puts("It's A Match")
      findJ(my_id, neighbor_id, new_j)
      new_j
    else
      j
    end
  end
end

# Take command line arguments
arguments = System.argv()

# Make them into integers
numNodes = String.to_integer(Enum.at(arguments, 0))
numRequests = String.to_integer(Enum.at(arguments, 1))

# Pass the integers to Actor 1
MAINPROJ.main(numNodes, numRequests)

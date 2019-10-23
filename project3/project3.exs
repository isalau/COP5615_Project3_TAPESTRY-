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

    keepAlive()
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
    # Node N requests a new ID new_id
    # IO.inspect(self(), label: "#{index}s pid")
    # Tapestry currently uses an identifier space of 160-bit values
    # Tapestry assumes nodeIDs and GUIDs are roughly evenly distributed in the namespace, which can be achieved by using a secure hashing algorithm like SHA-1
    random_number = :rand.uniform(10000)
    sha = :crypto.hash(:sha, "#{random_number}")
    new_id = sha |> Base.encode16()
    IO.inspect(new_id, label: "sha 1 output")

    numRequestToSend = numRequests

    neighborMap = []

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
  def handle_cast({:receiveNeighborMap, _n_id, _n_neighborMap}, _state) do
  end

  # Server
  @impl true
  def handle_call({:addToTapestry}, _from, state) do
    IO.inspect(state, label: "state")
    # state = index, new_id, numRequestToSend, neighborMap
    my_id = elem(state, 1)

    # OG = N as an object; objects routed by ID

    h_node_pid = contactGatewayNode(my_id, self())
    # IO.inspect(gNode, label: "GatewayNode'd ID is")

    # i is the level; 41 levels because 40 digits in id ???
    # For (i=0; hNode != NULL; i++) {}
    # QUESTION: What should hNodeToRoute return?
    hNodeToRoute(h_node_pid, 0, my_id, state)
    # Route to current surrogate via new_id;
    # Move relevant pointers off current surrogate;
    # Use surrogate(new_id) backptrs to notify nodes by flooding back levels to where surrogate routing first became necessary
    # routeToCurrentSurrogate(h_node_pid)
    {:reply, state, state}
  end

  # Server
  @impl true
  def handle_call({:receiveHello, neighbor_pid, neighbor_id}, _from, state) do
    my_id = elem(state, 1)
    IO.inspect(state, label: "#{my_id} received Hello from #{neighbor_id}. My old state")

    new_state = placeInNeighborMap(neighbor_pid, state, neighbor_id)
    IO.inspect(new_state, label: "#{my_id} new state")

    {:reply, state, state}
  end

  # Server
  @impl true
  def handle_call({:getHState}, _from, state) do
    # getting state
    {:reply, state, state}
  end

  ################# CLIENT ######################

  def stayAlive(keep) do
    if keep == true do
      stayAlive(true)
    end
  end

  def addToTapestry(childPid) do
    GenServer.call(childPid, {:addToTapestry}, :infinity)
  end

  def contactGatewayNode(_new_id, childPid) do
    children = DynamicSupervisor.which_children(TAPESTRY)
    # get a node from supervisor that is not yourself--> surrogate root
    {_, neighbor_id, _, _} = Enum.at(children, 1)

    if neighbor_id != childPid do
      # Returns Node G id
      _nodeG = neighbor_id
    else
      {_, neighbor_id, _, _} = Enum.at(children, 0)

      # Returns Node G state
      _nodeG = neighbor_id
    end
  end

  def hNodeToRoute(h_node_pid, _i, my_id, _my_state) do
    # Send Hello to neighbor no matter what so they can check if they need to add me to their map
    # QUESTION: Can I send direct hello?
    TAPNODE.sendHello(h_node_pid, self(), my_id)
    IO.puts("calling")
    h_state = getHState(h_node_pid)
    IO.inspect(h_state, label: "h_state")
    # h_state = :sys.get_state(h_node_pid)
    # h_neighbor_map = elem(h_state, 3)
    # # Grab ith level NeighborMap_i from H;
    # # check if that level is empty --> terminate when null entry found
    # i_level_neighbor_map = Enum.at(h_neighbor_map, i)
    #
    # if i_level_neighbor_map != nil do
    #   IO.puts("ith level NeighborMap_i from H: #{i_level_neighbor_map}")
    #
    #   # The new node stops copying neighbor maps when a neighbor map lookup shows an empty entry in the next hop.
    #   # For (j=0; j<baseOfID; j++) {}
    #   baseOfIDLoop(0)
    #   new_i = i + 1
    #   hNodeToRoute(hNode, i, new_i, state)
    # end
  end

  def getHState(h_node_pid) do
    h_state = GenServer.call(h_node_pid, {:getHState}, :infinity)
  end

  # stopping condition --> last level
  # def hNodeToRoute(_hNode, i, _new_id, _state) when i == 40 do
  #   # copy everything but recursion from below
  # end

  # stopping condition --> last level
  def baseOfIDLoop(j) when j == 40 do
    # Fill in jth level of MY neighbor map
    # updateYourNeighborMap()
    # H = NextHop(i+1, new_id);
  end

  def baseOfIDLoop(_j) do
    # Fill in jth level of MY neighbor map
    # updateYourNeighborMap()
    # H = NextHop(i+1, new_id);
    # new_j = j + 1
    # baseOfIDLoop(new_j)
  end

  def dist() do
    # neigh=sec.neighbor;
    # sec.neighbors=neigh−>sec.neighbors(i,j);
  end

  def routeToCurrentSurrogate(_surrogate_Node) do
    # routes to the current surrogate for new_id, and moves data meant for new_id to N
  end

  def routeToObject(_new_id) do
    # Return root node of where object is (or would be) located
    # Uses nextHop function?
  end

  def nextHop(_n, G) do
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
    # While (Dist(N, NM_i(j, neigh)) > min(eachDist(N, NM_i(j, sec.neigh)))) {}
    # dist()
  end

  def sendHello(neighbor_id, n_id, new_id) do
    # Node N sends hello to Neighbor new_neighbor  H(i)
    GenServer.call(neighbor_id, {:receiveHello, n_id, new_id}, :infinity)
  end

  def sendNeighborMap(neighbor_id, n_pid) do
    # Neighbor new_neighbor sends its neighbor map to Node N
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

  def placeInNeighborMap(_neighbor_pid, my_state, neighbor_id) do
    my_id = elem(my_state, 1)
    my_neighborMap = elem(my_state, 3)
    IO.inspect(my_state, label: "my state")

    # find j - compare characters to find what level it belongs to
    j = findJ(my_id, neighbor_id, 0)

    # find i
    i =
      if j > 0 do
        j_corrected = j - 1
        IO.puts("Length of most in common prefix #{j_corrected}")

        prefix = String.slice(my_id, 0..j_corrected)

        # find i
        i_index = j_corrected + 1
        i = String.at(neighbor_id, i_index)
        IO.puts("Common prefix between #{my_id} and #{neighbor_id} is #{prefix} and i is: #{i}")
        i
      else
        # i is the first elemment
        i = String.at(neighbor_id, 0)
        i
      end

    # Create dummy neighbor
    new_neighbor = [j, i, neighbor_id]

    # Check if level j exists & insert
    new_my_neighborMap =
      if(Enum.count(my_neighborMap) > 0) do
        if Enum.any?(my_neighborMap, fn x ->
             IO.puts("x is #{x}")
             x_j = Enum.at(x, 0)
             x_j == j
           end) == true do
          IO.puts("level j already exists")
        else
          IO.puts("level j not here yet")
          _new_my_neighborMap = my_neighborMap ++ [new_neighbor]
        end
      else
        IO.puts("level j not here yet")
        _new_my_neighborMap = my_neighborMap ++ [new_neighbor]
      end

    # update state
    temp_state = Tuple.delete_at(my_state, 3)
    _my_new_state = Tuple.insert_at(temp_state, 3, new_my_neighborMap)
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

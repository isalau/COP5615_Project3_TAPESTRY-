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
      # IO.puts("Child #{x} started")
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
    # IO.puts("Its #{index} here in DynamicSupervisor")
    {:ok, _pid} = DynamicSupervisor.start_link(__MODULE__, index, name: __MODULE__)
  end

  def start_child(index, numRequests) do
    # IO.puts("DynamicSupervisor adding #{index} child")

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
    # IO.inspect(new_id, label: "sha 1 output")

    numRequestToSend = numRequests

    neighborMap = %{}

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
  def handle_call({:addToTapestry}, _from, state) do
    IO.inspect(state, label: "\nMy Initial State")
    # state = index, new_id, numRequestToSend, neighborMap
    my_id = elem(state, 1)

    # OG = N as an object; objects routed by ID
    h_node_pid = contactGatewayNode(my_id, self())
    # IO.inspect(h_node_pid, label: "GatewayNode's pid is")

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
  def handle_call({:receiveHello, neighbor_id}, _from, state) do
    IO.inspect(state, label: "\nReceived Hello from #{neighbor_id}. My old state")
    new_state = placeInNeighborMap(state, neighbor_id)
    IO.inspect(new_state, label: "\nMy New state")

    {:reply, new_state, new_state}
  end

  # Server
  @impl true
  def handle_call({:addNewNeighbor, neighbor_id}, _from, state) do
    # IO.inspect(state, label: "#{my_id} received Hello from #{neighbor_id}. My old state")

    new_state = placeInNeighborMap(state, neighbor_id)
    # IO.inspect(new_state, label: "new state")

    {:reply, new_state, new_state}
  end

  # Server
  @impl true
  def handle_call({:getHNeighbors, i}, _from, state) do
    # getting state
    # get neighbor map from h
    {_, _neighbor_id, _, h_neighbor_map} = state

    # # check if  h_neighbor_map level is empty
    if h_neighbor_map != nil do
      # check if  i level is empty --> terminate when null entry found
      if checkIfLevelIExists(h_neighbor_map, i) == true do
        # Grab i level from h_neighbor_map;
        i_level = getLevelI(h_neighbor_map, i)
        count = Enum.count(i_level)
        # IO.inspect(i_level, label: "#{count} level #{i} NeighborMap_i from H")
        # get every item in that level and add to my neighbor list

        new_state = levelBylevel(i_level, state, count, 0)
        # //call other gensserver back 
        # Enum.each(i_level, fn x ->
        #   # neighbor_id = Enum.at(x, 1)
        #   # pid = self()
        #   # result = GenServer.call(pid, {:addNewNeighbor, neighbor_id}, :infinity)
        #   # GenServer.reply(pid, result)
        #   new_state = placeInNeighborMap(my_state, neighbor_id)
        # end)

        IO.inspect(new_state, label: "\nMy New State after H neighbors")
        {:reply, new_state, new_state}
      else
        {:reply, state, state}
      end
    else
      {:reply, state, state}
    end
  end

  # Server
  @impl true
  def handle_cast({:receiveNeighborMap, _n_id, _n_neighborMap}, _state) do
  end

  ################# CLIENT ######################

  def levelBylevel(i_level, my_state, count, j) do
    neighbor = Enum.at(i_level, j)
    # IO.inspect(neighbor, label: "In #{j} levelBylevel neighbor ")

    neighbor_id = Enum.at(neighbor, 1)
    # IO.inspect(neighbor_id, label: "In levelBylevel neighbor_id ")

    new_count = count - 1
    # IO.inspect(i_level, label: "In levelBylevel, count #{count}, new_count #{new_count} ")

    new_j = j + 1
    new_state = placeInNeighborMap(my_state, neighbor_id)

    if new_count > 0 do
      levelBylevel(i_level, new_state, new_count, new_j)
    else
      new_state
    end
  end

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

  # stopping condition --> last level
  # def hNodeToRoute(_hNode, i, _new_id, _state) when i == 40 do
  #   # copy everything but recursion from below
  # end

  def hNodeToRoute(h_node_pid, i, my_id, _my_state) do
    # Send Hello to neighbor no matter what so they can check if they need to add me to their map
    # QUESTION: Can I send direct hello like this?
    TAPNODE.sendHello(h_node_pid, self(), my_id)

    getHNeighbors(h_node_pid, i)
  end

  def getHNeighbors(h_node_pid, i) do
    GenServer.call(h_node_pid, {:getHNeighbors, i}, :infinity)
  end

  def checkIfLevelIExists(h_neighbor_map, i) do
    if(Enum.count(h_neighbor_map) > 0) do
      if Map.has_key?(h_neighbor_map, i) == true do
        true
      else
        false
      end
    else
      false
    end
  end

  def getLevelI(h_neighbor_map, i) do
    i_level_neighbor_map = Map.fetch(h_neighbor_map, i)

    # IO.inspect(i_level_neighbor_map, label: "#{i}th level NeighborMap_i from H")
    {_, i_level} = i_level_neighbor_map
    i_level
  end

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

  def dist() do
    # neigh=sec.neighbor;
    # sec.neighbors=neigh−>sec.neighbors(i,j);
  end

  def sendHello(neighbor_id, _n_id, new_id) do
    # Node N sends hello to Neighbor new_neighbor  H(i)
    GenServer.call(neighbor_id, {:receiveHello, new_id}, :infinity)
  end

  def sendNeighborMap(neighbor_id, n_pid) do
    # Neighbor new_neighbor sends its neighbor map to Node N
    # state = index, new_id, numRequestToSend, neighborMap
    # n_neighborMap = elem(state, 3)
    n_neighborMap = []
    GenServer.cast(neighbor_id, {:receiveNeighborMap, n_pid, n_neighborMap})
  end

  def sendMessageFunction(serverTo, serverFrom, msg) do
    # IO.inspect(serverTo, label: "in client sendMessageFunction serverTo")
    GenServer.call(serverTo, {:receiveMsg, {serverFrom, msg}})
  end

  def routeNode(N, Exact) do
    # A node N has a neighbor map with multiple levels, where each level contains links to nodes matching a prefix up to a digit position in the ID, and contains a number of entries equal to the ID’s base.
    # The primary ith entry in the jth level is the ID and location of the closest node that begins with prefix (N, j-1) + i
  end

  def placeInNeighborMap(my_state, neighbor_id) do
    my_id = elem(my_state, 1)
    # IO.inspect(neighbor_id, label: "my id is #{my_id} and neighbor_id")

    if(my_id != neighbor_id) do
      my_neighborMap = elem(my_state, 3)

      # find j - compare characters to find what level it belongs to
      j = findJ(my_id, neighbor_id, 0)

      # find i
      i =
        if j > 0 do
          j_corrected = j - 1
          # IO.puts("Length of most in common prefix #{j_corrected}")

          _prefix = String.slice(my_id, 0..j_corrected)

          # find i
          i_index = j_corrected + 1
          i = String.at(neighbor_id, i_index)

          # IO.puts("Common prefix between #{my_id} and #{neighbor_id} is #{prefix} and i is: #{i}")
          i
        else
          # i is the first elemment
          i = String.at(neighbor_id, 0)
          i
        end

      # Create dummy neighbor
      _new_neighbor = %{j => [i, neighbor_id]}

      # Check if level j exists & insert
      new_my_neighborMap =
        if(my_neighborMap != nil) do
          if Map.has_key?(my_neighborMap, j) == true do
            # if Enum.any?(my_neighborMap, fn x ->
            # IO.inspect(j, label: "level j")
            # level_j = Enum.at(x, 0)
            # IO.puts("level_j is #{level_j}")
            # x_j = Enum.at(level_j, 0)
            # IO.puts("x_j is #{x_j}")
            # x_j == j
            # end) == true do

            # _new_my_neighborMap = my_neighborMap ++ [new_neighbor]
            new_neighbor = [i, neighbor_id]
            _new_my_neighborMap = updateYourNeighborMap(j, my_neighborMap, new_neighbor)
          else
            # IO.puts("level j not here yet")

            # _new_my_neighborMap = my_neighborMap ++ [[new_neighbor]]
            _new_my_neighborMap = Map.put(my_neighborMap, j, [[i, neighbor_id]])
          end
        else
          # IO.puts("level j not here yet")
          # _new_my_neighborMap = my_neighborMap ++ [[new_neighbor]]
          _new_my_neighborMap = Map.put(my_neighborMap, j, [[i, neighbor_id]])
        end

      # update state
      temp_state = Tuple.delete_at(my_state, 3)
      _my_new_state = Tuple.insert_at(temp_state, 3, new_my_neighborMap)
    end
  end

  def findJ(my_id, neighbor_id, j) do
    # IO.inspect(j, label: "in findJ with #{my_id} and #{neighbor_id}")
    prefixA = String.slice(my_id, 0..j)
    # IO.inspect(prefixA, label: "prefixA")
    prefixB = String.slice(neighbor_id, 0..j)
    # IO.inspect(prefixB, label: "prefixB")
    new_j = j + 1

    if prefixA == prefixB do
      # IO.puts("It's A Match")
      findJ(my_id, neighbor_id, new_j)
      new_j
    else
      j
    end
  end

  def updateYourNeighborMap(j, my_neighborMap, new_neighbor) do
    # IO.inspect(new_neighbor, label: "new_neighbor")
    # j = Enum.at(new_neighbor, 0)
    # IO.inspect(j, label: "j")
    # i = Enum.at(new_neighbor, 1)
    # neighbor_id = Enum.at(new_neighbor, 2)

    # get j level
    # IO.inspect(my_neighborMap, label: "my_neighborMap")

    # updateedNeighborMap = IO.puts("here 1")

    {_current_neighbors, updateedNeighborMap} =
      Map.get_and_update(my_neighborMap, j, fn current_neighbors ->
        # IO.inspect(current_neighbors, label: "current_neighbors")
        update = current_neighbors ++ [new_neighbor]
        {current_neighbors, update}
      end)

    # IO.inspect(updateedNeighborMap, label: "updateedNeighborMap")
    updateedNeighborMap
  end
end

# level =
#   Enum.find(my_neighborMap, nil, fn level ->
#     IO.inspect(level, label: "level")
#     first_level_neighbor = Enum.at(level, 0)
#     IO.inspect(first_level_neighbor, label: "first_level_neighbor")
#     first_level_index = Enum.at(first_level_neighbor, 0)
#     IO.inspect(first_level_index, label: "first_level_index")
#
#     first_level_index == j
#   end)

# update j level
# new_j_level = [new_neighbor | level]
# do the distance formula thing
# While (Dist(N, NM_i(j, neigh)) > min(eachDist(N, NM_i(j, sec.neigh)))) {}
# dist()

# Take command line arguments
arguments = System.argv()

# Make them into integers
numNodes = String.to_integer(Enum.at(arguments, 0))
numRequests = String.to_integer(Enum.at(arguments, 1))

# Pass the integers to Actor 1
MAINPROJ.main(numNodes, numRequests)

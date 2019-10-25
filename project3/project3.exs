defmodule GLOBALSUP do
  use DynamicSupervisor

  def start_link(args) do
    # IO.puts("Its #{index} here in DynamicSupervisor")
    {:ok, _pid} = DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_child(numNodes, numRequests) do
    # IO.puts("DynamicSupervisor adding #{index} child")

    child_spec =
      Supervisor.child_spec({MAINPROJ, [numNodes, numRequests]},
        restart: :temporary
      )

    {:ok, _child} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(_index) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule MAINPROJ do
  use GenServer
  @impl true
  def init(opts) do
    IO.inspect(opts, label: "in init")
    numNodes = Enum.at(opts, 0)
    numRequests = Enum.at(opts, 1)
    main(numNodes, numRequests)
    {:ok, %{}}
  end

  def start_link(opts) do
    IO.inspect(opts, label: "in start link")
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @impl true
  def handle_cast({:mainStart, numNodes, numRequests}, state) do
    IO.puts("in mainStart 1")
    ################# STARTS SUPERVISOR ######################
    # # number of Nodes
    # numNodes = String.to_integer(Enum.at(argv, 0))
    #
    # # number of Requests
    # numRequests = String.to_integer(Enum.at(argv, 1))

    # Starting the dynamic Server
    {:ok, _pid} = TAPESTRY.start_link(1)
    IO.puts("in mainStart 2")
    ################# CREATES NUMBER OF NODES ######################
    # Range of GenServers
    rng = Range.new(1, numNodes)

    for x <- rng do
      TAPESTRY.start_child(x, numRequests)
      # IO.puts("Child #{x} started")
    end

    IO.puts("in mainStart 3")
    ################# CREATE OVERLAY NETWORK  ######################
    children = DynamicSupervisor.which_children(TAPESTRY)
    IO.puts("in mainStart 3.5")

    for x <- children do
      {_, childPid, _, _} = x
      TAPNODE.addToTapestry(childPid)
    end

    IO.puts("in mainStart 4")

    :timer.sleep(1000)

    for x <- children do
      {_, childPid, _, _} = x
      TAPNODE.printState(childPid)
    end

    IO.puts("in mainStart 5")
    ################# SEND FIRST REQUEST FROM ALL NODES ######################
    for x <- children do
      {_, childPid, _, _} = x
      # get random child from supervisor
      sendRandom(childPid, numNodes, numRequests)
    end

    IO.puts("in mainStart 6")
  end

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

    :timer.sleep(1000)

    for x <- children do
      {_, childPid, _, _} = x
      TAPNODE.printState(childPid)
    end

    for x <- children do
      {_, childPid, _, _} = x
      # get random child from supervisor
      sendRandom(childPid, numNodes, numRequests)
    end

    ################# SEND FIRST REQUEST FROM ALL NODES ######################
  end

  def keepAlive() do
    keepAlive()
  end

  def sendRandom(childPid, numNodes, numRequests) do
    children = DynamicSupervisor.which_children(TAPESTRY)
    randomChild = Enum.random(children)
    {_, randomChildpid, _, _} = randomChild

    if(randomChildpid == childPid) do
      sendRandom(childPid, numNodes, numRequests)
    else
      TAPNODE.sendRequest(childPid, randomChildpid)
    end

    numberOfResponses = numNodes * numRequests
    getMaxHops(numberOfResponses)
  end

  def getMaxHops(numberOfResponses) do
    # check to see if I have received all the number of responses I need
    # if someVariable == numberOfResponses do
    # else
    # wait some nodes still aren't done
    keepAlive()
    # end
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

    numRequestToSend = numRequests

    neighborMap = %{}

    objectList = []
    objectLinksList = []

    {:ok, _pid} =
      GenServer.start_link(
        __MODULE__,
        {index, new_id, numRequestToSend, neighborMap, objectList, objectLinksList}
      )
  end

  @impl true
  def init({index, new_id, numRequestToSend, neighborMap, objectList, objectLinksList}) do
    {:ok, {index, new_id, numRequestToSend, neighborMap, objectList, objectLinksList}}
  end

  @impl true
  def handle_call({:addToTapestry}, _from, state) do
    # pid = Kernel.inspect(self())
    # IO.inspect(state, label: "\nMy #{pid} Initial State")
    my_id = elem(state, 1)

    # OG = N as an object; objects routed by ID
    h_node_pid = contactGatewayNode(self())

    hNodeToRoute(h_node_pid, my_id)
    # IO.inspect(state, label: "\nAdded To Tapestry")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:receiveHello, neighbor_id}, from, state) do
    # _pid = Kernel.inspect(self())

    # _fid = Kernel.inspect(from_pid)
    # IO.inspect(state, label: "\n #{pid} Received Hello from #{fid}. \nMy old state")
    # IO.inspect(state, label: "\nReceived Hello from #{neighbor_id}. \nMy old state")

    {from_pid, _ok} = from
    new_state = placeInNeighborMap(state, neighbor_id, from_pid)

    # IO.inspect(new_state, label: "\nMy new state")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:populateNeighbors, my_id, my_pid}, _from, state) do
    # IO.inspect(my_pid, label: "\nIn populateNeighbors server. My pid is")
    # get neighbor map from h
    # {from_pid, _ok} = from
    {_, neighbor_id, _, neighbor_map, _, _} = state
    j = findJ(my_id, neighbor_id, 0)
    i = j + 1
    # check if level exists
    if(checkIfLevelExists(neighbor_map, j) == true) do
      # go to that level on the Map
      level = getLevel(neighbor_map, j)
      # IO.inspect(level, label: "level")

      # check if there is a neighbor with the same "i" as you
      iInList =
        Enum.any?(level, fn elem ->
          n_i = Enum.at(elem, 0)
          n_i == i
        end)

      if iInList == true do
        neighbor =
          Enum.find(level, fn elem ->
            n_i = Enum.at(elem, 0)
            n_i == i
          end)

        # get close item and route there
        # check it make sure it's not you
        # neighbor = Enum.at(level, 0)
        next_neighbor_id = Enum.at(neighbor, 1)
        next_neighbor_pid = Enum.at(neighbor, 2)
        new_j = j + 1
        # IO.puts("here 1")

        if next_neighbor_id != my_id do
          GenServer.call(next_neighbor_pid, {:routeN, new_j, my_id, my_pid}, :infinity)
        end
      else
        # IO.inspect(level, label: "level")
        # copy level map
        for elem <- level do
          # IO.inspect("should add friend")
          n_id = Enum.at(elem, 1)
          n_pid = Enum.at(elem, 2)
          GenServer.cast(my_pid, {:addToNeighborMap, n_id, n_pid})
        end

        # get close item and route there
        # check it make sure it's not you
        neighbor = Enum.at(level, 0)
        next_neighbor_id = Enum.at(neighbor, 1)
        next_neighbor_pid = Enum.at(neighbor, 2)
        new_j = j + 1
        # IO.puts("here 1")

        if next_neighbor_id != my_id do
          GenServer.call(next_neighbor_pid, {:routeN, new_j, my_id, my_pid}, :infinity)
        end
      end

      # IO.puts("here 2")
    else
      # IO.inspect("i don't know")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:routeN, j, my_id, my_pid}, _from, state) do
    # in neighbors state
    {_, _neighbor_id, _, neighbor_map, _, _} = state
    # IO.inspect(my_pid, label: "In routeN looking from #{j} neighbor_id")
    # # check if level exists
    if(checkIfLevelExists(neighbor_map, j) == true) do
      # IO.inspect("level #{j} exists")
      # go to that level on the Map
      level = getLevel(neighbor_map, j)
      # get close item and route there
      neighbor = Enum.at(level, 0)
      next_neighbor_id = Enum.at(neighbor, 1)
      next_neighbor_pid = Enum.at(neighbor, 2)
      new_j = j + 1

      if next_neighbor_id != my_id do
        GenServer.call(next_neighbor_pid, {:routeN, new_j, my_id, my_pid}, :infinity)
      end
    else
      # IO.inspect("i don't know")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:getHNeighbors}, from, state) do
    # _pid = Kernel.inspect(self())
    # IO.inspect(state, label: "\nIn getHNeighbors server. My pid is #{pid} and my state is")
    # get neighbor map from h
    {from_pid, _ok} = from
    {_, neighbor_id, _, h_neighbor_map, _, _} = state
    placeInNeighborMap(state, neighbor_id, from_pid)

    # check if  h_neighbor_map level is empty
    if h_neighbor_map != nil do
      _level_count = Enum.count(h_neighbor_map)
      level = 0
      # go through every level of neighbor list
      levels(h_neighbor_map, level, from)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:printState}, _from, state) do
    pid = Kernel.inspect(self())
    IO.inspect(state, label: "\n My #{pid} State is")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:getState}, _from, state) do
    # _pid = Kernel.inspect(self())
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:addToNeighborMap, neighbor_id, from_pid}, state) do
    # IO.inspect(self(), label: "In add to neighbor map with #{neighbor_id} ")
    new_state = placeInNeighborMap(state, neighbor_id, from_pid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:LevelToLevel, i_level, count, from_pid}, state) do
    # _pid = Kernel.inspect(self())

    # IO.inspect(state,
    #   label: "\nIn LevelToLevel server. My pid is #{pid} and my state before H neighbors"
    # )

    new_state = levelBylevel(i_level, state, count, 0, from_pid)

    # IO.inspect(new_state,
    #   label: "\n\nIn LevelToLevel server. My pid is #{pid} and my state after H neighbors"
    # )

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:sendMessage, target_pid}, state) do
    target_state = GenServer.call(target_pid, {:getState}, :infinity)

    routeToObject(target_state, target_pid, state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:receiveMessage, msg}, state) do
    IO.inspect("I received a message and it took #{msg} hops")
    {:noreply, state}
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

  def contactGatewayNode(childPid) do
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

  def hNodeToRoute(h_node_pid, my_id) do
    # pid = Kernel.inspect(self())
    # IO.inspect(pid, label: "\nMy PiD ")

    # Send Hello to neighbor no matter what so they can check if they need to add me to their map
    sendHello(h_node_pid, self(), my_id)

    GenServer.call(h_node_pid, {:populateNeighbors, my_id, self()}, :infinity)
    # getHNeighbors(h_node_pid)
  end

  def sendHello(neighbor_id, _n_id, new_id) do
    # Node N sends hello to Neighbor new_neighbor  H(i)
    GenServer.call(neighbor_id, {:receiveHello, new_id}, :infinity)
  end

  def placeInNeighborMap(my_state, neighbor_id, from_pid) do
    # pid = Kernel.inspect(self())
    my_id = elem(my_state, 1)
    # IO.inspect(neighbor_id, label: "\nPlaceInNeighborMap my id is #{pid} and neighbor_id")

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

      # neighbor
      # %{j => [i, neighbor_id, neighbor_pid]}

      # Check if level j exists & insert
      new_my_neighborMap =
        if(my_neighborMap != nil) do
          if Map.has_key?(my_neighborMap, j) == true do
            new_neighbor = [i, neighbor_id, from_pid]

            _new_my_neighborMap =
              updateYourNeighborMap(j, my_neighborMap, new_neighbor, from_pid, my_id)
          else
            # IO.puts("level j not here yet")
            GenServer.cast(from_pid, {:addToNeighborMap, my_id, self()})
            _new_my_neighborMap = Map.put(my_neighborMap, j, [[i, neighbor_id, from_pid]])
          end
        else
          # IO.puts("level j not here yet")
          GenServer.cast(from_pid, {:addToNeighborMap, my_id, self()})
          _new_my_neighborMap = Map.put(my_neighborMap, j, [[i, neighbor_id, from_pid]])
        end

      # update state
      temp_state = Tuple.delete_at(my_state, 3)
      _my_new_state = Tuple.insert_at(temp_state, 3, new_my_neighborMap)
    else
      my_state
    end
  end

  def findJ(my_id, neighbor_id, j) do
    # IO.inspect(j, label: "in findJ with #{my_id} and #{neighbor_id}")
    prefixA = String.slice(my_id, 0..j)
    # IO.inspect(prefixA, label: "prefixA")
    prefixB = String.slice(neighbor_id, 0..j)
    # IO.inspect(prefixB, label: "prefixB")

    if prefixA == prefixB do
      # IO.puts("It's A Match")
      new_j = j + 1
      findJ(my_id, neighbor_id, new_j)
      # new_j
    else
      j
    end
  end

  def findI(senderPid, receiverPid, j) do
    i =
      if j > 0 do
        j_corrected = j - 1
        # IO.puts("Length of most in common prefix #{j_corrected}")
        _prefix = String.slice(senderPid, 0..j_corrected)
        i_index = j_corrected + 1
        i = String.at(receiverPid, i_index)
        i
      else
        # i is the first elemment
        i = String.at(receiverPid, 0)
        i
      end

    i
  end

  def updateYourNeighborMap(j, my_neighborMap, new_neighbor, from_pid, my_id) do
    {_current_neighbors, updateedNeighborMap} =
      Map.get_and_update(my_neighborMap, j, fn current_neighbors ->
        # IO.inspect(current_neighbors, label: "current_neighbors")
        # check for duplicates
        if Enum.member?(current_neighbors, new_neighbor) do
          {current_neighbors, current_neighbors}
        else
          GenServer.cast(from_pid, {:addToNeighborMap, my_id, self()})
          update = current_neighbors ++ [new_neighbor]
          sorted_update = Enum.sort(update)
          {current_neighbors, sorted_update}
        end
      end)

    # IO.inspect(updateedNeighborMap, label: "updateedNeighborMap")
    updateedNeighborMap
  end

  def getHNeighbors(h_node_pid) do
    # pid = Kernel.inspect(self())
    # IO.inspect(pid, label: "\nIn getHNeighbors client. My pid is ")
    GenServer.call(h_node_pid, {:getHNeighbors}, :infinity)
    # IO.inspect(new_state, label: "\nAfter getHNeighbors")
    # new_state
  end

  def getLevel(h_neighbor_map, i) do
    i_level_neighbor_map = Map.fetch(h_neighbor_map, i)

    # IO.inspect(i_level_neighbor_map, label: "#{i}th level NeighborMap_i from H")
    {_, i_level} = i_level_neighbor_map
    i_level
  end

  def levels(h_neighbor_map, level, from) do
    # check if  i level is empty --> terminate when null entry found
    if checkIfLevelExists(h_neighbor_map, level) == true do
      # Grab i level from h_neighbor_map;
      i_level = getLevel(h_neighbor_map, level)
      count = Enum.count(i_level)
      {from_pid, _ok} = from
      # IO.inspect(self(), label: "self")
      # IO.inspect(from_pid, label: "from_pid")
      # IO.inspect(i_level, label: "#{count} level #{i} NeighborMap_i from H")

      # get every item in that level and add to my neighbor list
      GenServer.cast(from_pid, {:LevelToLevel, i_level, count, from_pid})
      next_level = level + 1
      levels(h_neighbor_map, next_level, from)
    end
  end

  def levelBylevel(i_level, my_state, count, j, from_pid) do
    # pid = Kernel.inspect(self())

    # IO.inspect(my_state,
    # label: "\nIn LevelToLevel client. My pid is #{pid} and my state is"
    # )

    neighbor = Enum.at(i_level, j)
    # IO.inspect(neighbor, label: "\nLevelBylevel neighbor ")

    neighbor_id = Enum.at(neighbor, 1)
    neighbor_pid = Enum.at(neighbor, 2)
    # IO.inspect(neighbor_id, label: "LevelBylevel neighbor_id")

    new_count = count - 1
    # IO.inspect(i_level, label: "\nIn levelBylevel, count #{count}, new_count #{new_count} ")

    new_j = j + 1
    new_state = placeInNeighborMap(my_state, neighbor_id, neighbor_pid)

    if new_count > 0 do
      levelBylevel(i_level, new_state, new_count, new_j, from_pid)
    else
      new_state
    end
  end

  def checkIfLevelExists(h_neighbor_map, i) do
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

  def printState(childPid) do
    GenServer.call(childPid, {:printState}, :infinity)
  end

  def routeToCurrentSurrogate(_surrogate_Node) do
    # routes to the current surrogate for new_id, and moves data meant for new_id to N
  end

  def sendRequest(senderPid, receiverPid) do
    GenServer.cast(senderPid, {:sendMessage, receiverPid})
  end

  def routeToObject(target_state, target_pid, my_state) do
    # Return root node of where object is (or would be) located
    {_, target_id, _, _neighbor_map, _, _} = target_state
    {_, my_id, _, my_neighbor_map, _, _} = my_state

    # find prefix match length
    j = findJ(my_id, target_id, 0)

    # check if level exists
    if(checkIfLevelExists(my_neighbor_map, j) == true) do
      # go to that level on the Map
      level = getLevel(my_neighbor_map, j)

      # find i
      i = findI(my_id, target_id, j)

      # check to see if neighbor is in map
      dummy_neighbor = [i, target_id, target_pid]

      if Enum.member?(level, dummy_neighbor) == true do
        # route automatically there
        # IO.puts("I have them as a neighbor")
        msg = 1
        TAPNODE.sendDirectMessage(target_pid, msg)
      else
        IO.inspect("I don't have them as a neighbor")
        # try and find closests
        findNextHop(level, i, target_id, target_pid, 0, 1)
      end
    else
      IO.inspect("I don't have them as a neighbor")
      # level doesn't exist --> just get first level
      {_, level} = Enum.at(my_neighbor_map, 0)
      findNextHop(level, 0, target_id, target_pid, 0, 1)
    end
  end

  def findNextHop(level, i, target_id, target_pid, n, msg) do
    # check if there is a neighbor with the same "i" as you

    iInList =
      Enum.any?(level, fn elem ->
        n_i = Enum.at(elem, 0)
        n_i == i
      end)

    if iInList == true do
      neighbor =
        Enum.find(level, fn elem ->
          n_i = Enum.at(elem, 0)
          n_i == i
        end)

      # get close item and route there
      next_neighbor_pid = Enum.at(neighbor, 2)

      if(next_neighbor_pid != self()) do
        nextHop(next_neighbor_pid, target_id, target_pid, n, msg)
      else
        # need to find another neighbor that isn't me
      end
    else
      # no i just take first one from row
      neighbor = Enum.at(level, 0)
      next_neighbor_pid = Enum.at(neighbor, 2)

      if(next_neighbor_pid != self()) do
        nextHop(next_neighbor_pid, target_id, target_pid, n, msg)
      else
        # need to find another neighbor that isn't me
      end
    end
  end

  def nextHop(neighbor_pid, target_id, target_pid, n, msg) do
    # look at level n of my neighbor_map
    IO.inspect("In next hop")
    neighbor_state = GenServer.call(neighbor_pid, {:getState}, :infinity)
    {_, _neighbor_id, _, neighbor_map, _, _} = neighbor_state
    # check if level exists
    if(checkIfLevelExists(neighbor_map, n) == true) do
      IO.inspect("in next hop level exists")
      # go to that level on the Map
      level = getLevel(neighbor_map, n)
      # check to see if neighbor is in map

      # look at index i (n+1) of level n
      index = n + 1
      new_msg = msg + 1
      dummy_neighbor = [index, target_id, target_pid]

      if Enum.member?(level, dummy_neighbor) == true do
        IO.inspect("next hop found the target")
        TAPNODE.sendDirectMessage(target_pid, new_msg)
      else
        findNextHop(level, index, target_id, target_pid, index, new_msg)
      end
    else
      # go to neighbor on previous level; can't go further
      # get previous level
      previous_n = n - 1

      if(checkIfLevelExists(neighbor_map, previous_n) == true) do
        IO.inspect("in next hop level does not exists")
        # go to that level on the Map
        previous_level = getLevel(neighbor_map, previous_n)
        # check to see if neighbor is in map

        # look at index i (n+1) of level n
        index = previous_n + 1
        new_msg = msg + 1
        dummy_neighbor = [index, target_id, target_pid]

        if Enum.member?(previous_level, dummy_neighbor) == true do
          IO.inspect("next hop found the target")
          TAPNODE.sendDirectMessage(target_pid, new_msg)
        else
          # get closests neighbor
          iInList =
            Enum.any?(previous_level, fn elem ->
              n_i = Enum.at(elem, 0)
              n_i == index
            end)

          if iInList == true do
            neighbor =
              Enum.find(previous_level, fn elem ->
                n_i = Enum.at(elem, 0)
                n_i == index
              end)

            # get close item and route there
            next_neighbor_pid = Enum.at(neighbor, 2)

            if(next_neighbor_pid != self()) do
              nextHop(next_neighbor_pid, target_id, target_pid, n, msg)
            else
              # need to find another neighbor that isn't me
            end
          else
            # no i just take first one from row
            neighbor = Enum.at(previous_level, 0)
            next_neighbor_pid = Enum.at(neighbor, 2)

            if(next_neighbor_pid != self()) do
              nextHop(next_neighbor_pid, target_id, target_pid, n, msg)
            else
              # need to find another neighbor that isn't me
            end
          end
        end
      end
    end
  end

  def sendDirectMessage(receiverPid, msg) do
    GenServer.cast(receiverPid, {:receiveMessage, msg})
  end
end

# Take command line arguments
arguments = System.argv()

# Make them into integers
numNodes = String.to_integer(Enum.at(arguments, 0))
numRequests = String.to_integer(Enum.at(arguments, 1))

# Starting the dynamic Server
args = [numNodes, numRequests]
{:ok, _pid} = GLOBALSUP.start_link(args)

GLOBALSUP.start_child(numNodes, numRequests)

# {_, mainproj_pid} = GenServer.start_link(MAINPROJ, :ok)
# GenServer.cast(mainproj_pid, {:mainStart, numNodes, numRequests})

# Pass the integers to Actor 1
# MAINPROJ.main(numNodes, numRequests)

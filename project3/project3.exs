defmodule PROJECT3 do
  @moduledoc """
  Documentation for PROJECT3.
  """

  @doc """
  Hello world.

  ## Examples

      iex> PROJECT3.hello()
      :world

  """
  def main(argv) do
    ################# STARTS SUPERVISOR ######################
    # number of Nodes
    numNodes = String.to_integer(Enum.at(argv, 0))

    # number of Requests
    numRequests = String.to_integer(Enum.at(argv, 1))

    # Range of GenServers
    rng = Range.new(1, numNodes)

    # Starting the dynamic Server
    {:ok, pid} = DySupervisor.start_link(1)

    ################# CREATES NUMBER OF NODES ######################

    ################# ADDS NODES TO TAPESTRY ######################
    ################# ADSS NODES TO SUPERVISOR ######################
    for x <- rng do
      nl = []
      DySupervisor.start_child(nl, x)
      IO.puts("Child started #{x}")
    end

    ################# START ALL NODES ######################
  end

  def hello do
    :world
  end
end

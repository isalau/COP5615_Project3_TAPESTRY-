defmodule PROJECT3Test do
  use ExUnit.Case
  doctest PROJECT3

  test "greets the world" do
    assert PROJECT3.hello() == :world
  end
end

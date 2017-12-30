defmodule Project4part1finalTest do
  use ExUnit.Case
  doctest Project4part1final

  test "greets the world" do
    assert Project4part1final.hello() == :world
  end
end

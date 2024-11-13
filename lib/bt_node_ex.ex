defmodule BT.Node do
  @doc false
  defmacro __using__(_opts) do
    quote do
      def child_result(_res, node_state, game_state) do
        {Continue, node_state, game_state}
      end

      def new(_game_state, node_state) do
        {Continue, node_state}
      end

      def procpacket(_p, node_state, _game_state) do
        {Continue, node_state}
      end

      def tick(node_state, _game_state) do
        {Continue, node_state}
      end

      def recurrent_conditions(nod, state) do
        Continue
      end

      def log_new(initparams) do
        time = String.slice("#{NaiveDateTime.utc_now()}", 0..-4)
        IO.puts("-> #{time} #{__MODULE__} #{prettyprint(initparams)}")
      end

      def log_success() do
        time = String.slice("#{NaiveDateTime.utc_now()}", 0..-4)
        IO.puts("<- #{time} #{__MODULE__} success")
      end

      def log_fail(fail_reason) do
        time = String.slice("#{NaiveDateTime.utc_now()}", 0..-4)
        IO.puts("<- #{time} #{__MODULE__} fail #{inspect(fail_reason)}")
      end

      def prettyprint(initparams) do
        inspect(initparams)
      end

      defoverridable child_result: 3, new: 2, tick: 2, procpacket: 3, recurrent_conditions: 2, prettyprint: 1
    end
  end

  def bt_head(state, {nodemod, initparams, {Continue, nodest}}) do
    bt_head(state, {nodemod, initparams, {Continue, nodest, state}})
  end

  def bt_head(state, {nodemod, initparams, {Continue, nodest, newstate}}) do
    # IO.inspect({:bt_head, :with_continue, nodest})
    nbt = [{nodemod, initparams, nodest} | state.bt_state]
    %{newstate | bt_state: nbt}
  end

  def bt_head(state, {nodemod, initparams, {AddNodes, nodes}}) do
    nbt = nodes ++ [{nodemod, initparams, %{}} | state.bt_state]
    bt_head(%{state | bt_state: nbt}, nil)
  end

  def bt_head(state, {nodemod, initparams, {AddNodes, nodes, nodest}}) do
    nbt = nodes ++ [{nodemod, initparams, nodest} | state.bt_state]
    bt_head(%{state | bt_state: nbt}, nil)
  end

  def bt_head(state, {nodemod, initparams, {AddNodes, nodes, nodest, newstate}}) do
    nbt = nodes ++ [{nodemod, initparams, nodest} | state.bt_state]
    bt_head(%{newstate | bt_state: nbt}, nil)
  end

  def bt_head(state, {nodemod, initparams, {ReplaceNodes, nodes}}) do
    nbt = nodes ++ state.bt_state
    bt_head(%{state | bt_state: nbt}, nil)
  end

  def bt_head(state, {nodemod, initparams, {ReplaceNodes, nodes, newstate}}) do
    nbt = nodes ++ state.bt_state
    bt_head(%{newstate | bt_state: nbt}, nil)
  end

  def bt_head(state, {_nodemod, _initparams, {Reset, _nodes, newstate}}) do
    %{newstate | bt_state: [List.last(state.bt_state)]}
  end

  # new node constructor
  def bt_head(state = %{bt_state: [{nodemod, initparams} | tail]}, _) do
    nodemod.log_new(initparams)
    res = nodemod.new(state, initparams)
    bt_head(%{state | bt_state: tail}, {nodemod, initparams, res})
  end

  def bt_head(state, res) do
    case state.bt_state do
      [] when res == nil ->
        state

      [] ->
        case res do
          {nodemod, _, {Success, _}} ->
            nodemod.log_success()
            state

          {nodemod, _, {Success, _, new_state}} ->
            nodemod.log_success()
            new_state

          {nodemod, _, {Fail, fail_reason}} ->
            nodemod.log_fail(fail_reason)
            state

          {nodemod, _, {Fail, fail_reason, new_state}} ->
            nodemod.log_fail(fail_reason)
            new_state
        end

      [{nodemod, initparams, node_state} | tail] ->
        # if carryng a result, give to it
        case res do
          {rnodemod, _rinitparams, carry_res} ->
            {carry_res, new_state} =
              case carry_res do
                {Success, _} ->
                  rnodemod.log_success()
                  {carry_res, state}

                {Success, _, new_state} ->
                  rnodemod.log_success()
                  {carry_res, new_state}

                {Fail, fail_reason} ->
                  rnodemod.log_fail(fail_reason)
                  {carry_res, state}

                {Fail, fail_reason, new_state} ->
                  rnodemod.log_fail(fail_reason)
                  {carry_res, new_state}

                {_, _} ->
                  {carry_res, state}

                {_, _, new_state} ->
                  {carry_res, new_state}
              end

            res = nodemod.child_result(carry_res, node_state, new_state)
            bt_head(%{state | bt_state: tail}, {nodemod, initparams, res})

          _ ->
            state
        end
    end
  end
end

defmodule BT.Queue do
  use BT.Node

  def new(_game_state = %{}, [next_node | tail]) do
    {AddNodes, [next_node], %{queue: tail}}
  end

  def child_result(
        _,
        node_state = %{queue: [next_node | tail]},
        _game_state
      ) do
    {AddNodes, [next_node], %{node_state | queue: tail}}
  end

  def child_result(
        _,
        node_state = %{queue: []},
        _game_state
      ) do
    {Success, %{node_state | queue: []}}
  end
end

defmodule BT.Sequence do
  use BT.Node

  def new(_game_state = %{}, [next_node | tail]) do
    {AddNodes, [next_node], %{queue: tail}}
  end

  def child_result({Fail, _child_state}, node_state, _game_state) do
    {Fail, node_state}
  end

  def child_result({Success, _child_state}, node_state = %{queue: []}, _game_state) do
    {Success, node_state}
  end

  def child_result(
        {Success, _child_state},
        node_state = %{queue: [next_node | tail]},
        _game_state
      ) do
    {AddNodes, [next_node], %{node_state | queue: tail}}
  end
end

defmodule BT.Selector do
  use BT.Node

  def new(_game_state = %{}, [next_node | tail]) do
    {AddNodes, [next_node], %{queue: tail}}
  end

  def child_result({Fail, _child_state}, node_state = %{queue: []}, _game_state) do
    {Fail, node_state}
  end

  def child_result(
        {Fail, _child_state},
        node_state = %{queue: [next_node | tail]},
        _game_state
      ) do
    {AddNodes, [next_node], %{node_state | queue: tail}}
  end

  def child_result({Success, _child_state}, node_state, _game_state) do
    {Success, node_state}
  end
end

defmodule BT.Helper do
  def bt_proc_packets(packets, state) do
    Enum.reduce(packets, state, &bt_proc_packet(&1, &2))
  end

  def bt_proc_packet(packet, state) do
    state = BT.Node.bt_head(state, nil)

    case state.bt_state do
      [] ->
        state

      [{nodemod, initparams, nodest} | tail] ->
        res = nodemod.procpacket(packet, nodest, state)
        BT.Node.bt_head(%{state | bt_state: tail}, {nodemod, initparams, res})
    end
  end

  def bt_run_tick(state) do
    state = BT.Node.bt_head(state, nil)

    state = run_recurrent_conditions(state.bt_state, state)

    state = BT.Node.bt_head(state, nil)

    case state.bt_state do
      # empty bt
      [] ->
        state

      [{nodemod, initparams, nodest} | tail] ->
        # share bt state
        res = nodemod.tick(nodest, state)
        BT.Node.bt_head(%{state | bt_state: tail}, {nodemod, initparams, res})
    end
  end

  # bt_state
  def run_recurrent_conditions([], state) do
    state
  end

  def run_recurrent_conditions([top | rest], state) do
    case top do
      {nodemod, initparams, nodest} ->
        result = nodemod.recurrent_conditions(nodest, state)
        # IO.inspect {"running recurrent conditions", nodemod, result}
        case result do
          f = {Fail, _reason} ->
            BT.Node.bt_head(%{state | bt_state: rest}, {nodemod, initparams, f})

          f = {Success, _reason} ->
            BT.Node.bt_head(%{state | bt_state: rest}, {nodemod, initparams, f})

          _ ->
            run_recurrent_conditions(rest, state)
        end

      # uninitialized node
      {_, _} ->
        run_recurrent_conditions(rest, state)
    end
  end
end


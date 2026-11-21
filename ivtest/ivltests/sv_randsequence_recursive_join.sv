// IEEE 1800-2017/2023 18.17.5 through 18.17.7.
module sv_randsequence_recursive_join;
  timeunit 1ns;
  timeprecision 1ns;

  function automatic bit [63:0] cycle(int seed);
    process owner = process::self();
    int depth = 0, peers = 0, tails = 0;
    int marks[1:3];
    bit [63:0] trace = 0;
    foreach (marks[i]) marks[i] = 0;
    owner.srandom(seed);
    randsequence (main)
      main : { depth++; trace = (trace << 4) | 64'(depth); }
             if (depth < 4) joined(depth)
             { tails++; };
      joined(int depth_at_entry) : rand join main peer(depth_at_entry);
      peer(int n) :
        { if (marks[n] !== 0) $fatal(1, "duplicate peer start at depth %0d", n);
          marks[n] = 1; trace = (trace << 4) | 64'(4+n); }
        { if (marks[n] !== 1) $fatal(1, "peer completed out of order at depth %0d", n);
          marks[n] = 2; peers++; trace = (trace << 4) | 64'(7+n); };
    endsequence
    if (depth !== 4 || peers !== 3 || tails !== 4)
      $fatal(1, "join-edge cycle depth=%0d peers=%0d tails=%0d", depth, peers, tails);
    foreach (marks[i])
      if (marks[i] !== 2) $fatal(1, "missing peer at depth %0d", i);
    return trace;
  endfunction

  task automatic check_values(int base);
    process owner = process::self();
    int actuals = 0, visits = 0;
    int copied[0:1];
    time started = $time;
    foreach (copied[i]) copied[i] = -1;
    randsequence (joined)
      joined : rand join work(.tag(base + actuals++), .result(copied[0]))
                         work(base + actuals++, copied[1]);
      work(input int tag, output int result, input bit [2:0] delta = 11) :
        { if (actuals !== 2 || delta !== 3)
            $fatal(1, "lane actuals must be captured on join entry");
          tag += 2; }
        value(tag)
        { if ($left(value) !== 1 || $right(value) !== 2 || value[1] !== 100 + tag)
            $fatal(1, "first lane result at tag %0d", tag);
          tag -= 2; }
        value(tag + delta)
        { if (value[1] !== 102 + tag || value[2] !== 103 + tag)
            $fatal(1, "lane result array at tag %0d", tag);
          result = value[1] + value[2]; }
        { if (copied[tag-base] !== -1)
            $fatal(1, "lane output was copied before completion"); };
      int value(int n) :
        { if (process::self() != owner) $fatal(1, "lane changed process");
          visits++;
          if (n == 0) begin
            #1;
            return 100;
          end }
        value(n-1)
        { return value + 1; };
    endsequence
    if (actuals !== 2 || copied[0] !== 205 + 2*base || copied[1] !== 207 + 2*base ||
        visits !== 4*base + 16 || $time !== started + 4)
      $fatal(1, "independent lane captures, output copy-back, or recursive calls");
  endtask

  task automatic check_exits(int mode);
    int leaf_visits = 0, loop_visits = 0, lane_returns = 0, unwinds = 0, root_tail = 0;
    int inner_trace = 0, outer_trace = 0;
    int inner_at_break = -1, outer_at_break = -1;
    int copied = -1;
    randsequence (main)
      main : descend(2, copied) { root_tail++; };
      descend(input int n, output int out) :
        if (n > 0) descend(n-1, out) else outer { unwinds++; out = n; };
      outer : rand join inner outer_peer;
      inner : rand join cut inner_peer;
      cut : leaf(2)
        { repeat (3) begin
            loop_visits++;
            break;
          end
          if (mode == 1) begin
            inner_at_break = inner_trace; outer_at_break = outer_trace;
            break;
          end
          lane_returns++;
          return; }
        { $fatal(1, "direct lane return did not skip its tail"); };
      leaf(int n) :
        { leaf_visits++; }
        if (n > 0) leaf(n-1)
        { if (n == 0 && mode == 2) begin
            inner_at_break = inner_trace; outer_at_break = outer_trace;
            break;
          end
          return; }
        { $fatal(1, "called production return did not skip its tail"); };
      inner_peer : { inner_trace = 1; } { inner_trace = 10*inner_trace + 2; };
      outer_peer : { outer_trace = 3; } { outer_trace = 10*outer_trace + 4; };
    endsequence
    if (leaf_visits !== 3 || loop_visits !== (mode == 2 ? 0 : 1))
      $fatal(1, "recursive leaf or lane loop had incorrect control flow");
    if (mode == 0) begin
      if (lane_returns !== 1 || inner_trace !== 12 || outer_trace !== 34 ||
          unwinds !== 3 || root_tail !== 1 || copied !== 2)
        $fatal(1, "lane or called production return escaped its activation");
    end else if (lane_returns !== 0 || unwinds !== 0 || root_tail !== 0 || copied !== -1 ||
                 inner_at_break < 0 || outer_at_break < 0 ||
                 inner_trace !== inner_at_break || outer_trace !== outer_at_break)
      $fatal(1, "sequence break failed to unwind the nested joins and their callers");
  endtask

  task automatic check_priority(int mode, int seed);
    process owner = process::self();
    int unsigned draw, next_draw;
    int order = 0;
    bit short_first;
    owner.srandom(seed);
    draw = $urandom;
    next_draw = $urandom;
    // One versus three remaining items gives the short lane a first-step
    // weight of 3/4, 1/4, or 1/2 at the endpoints or midpoint.
    case (mode)
      0: short_first = draw < 32'hc0000000;
      1: short_first = draw < 32'h40000000;
      default: short_first = draw < 32'h80000000;
    endcase
    owner.srandom(seed);
    randsequence (main)
      main : case (mode)
        0: shortest;
        1: longest;
        2: midpoint;
        default: unspecified;
      endcase;
      shortest : rand join (0.0) short_lane long_lane;
      longest : rand join (1.0) short_lane long_lane;
      midpoint : rand join (0.5) short_lane long_lane;
      unspecified : rand join short_lane long_lane;
      short_lane : marker(1);
      long_lane : { order = 10*order + 2; return; }
                  { $fatal(1, "returned lane remained eligible"); }
                  { $fatal(1, "returned lane remained eligible"); };
      marker(int n) :
        if (n > 0) marker(n-1) else append;
      append : { order = 10*order + 1; };
    endsequence
    if (order !== (short_first ? 12 : 21) || $urandom !== next_draw)
      $fatal(1, "join priority or live-lane RNG consumption mode=%0d seed=%0d order=%0d",
             mode, seed, order);
  endtask

  initial begin
    bit [63:0] first_trace, trace;
    bit varied;
    varied = 0;
    first_trace = cycle(3971);
    for (int seed = 3971; seed < 3987; seed++) begin
      trace = cycle(seed);
      if (trace !== cycle(seed)) $fatal(1, "join choice did not replay for seed %0d", seed);
      if (trace != first_trace) varied = 1;
    end
    if (!varied) $fatal(1, "seeds produced no interleaving variation");
    fork
      check_values(3);
      check_values(8);
    join
    for (int mode = 0; mode < 3; mode++) check_exits(mode);
    for (int mode = 0; mode < 4; mode++)
      for (int count = 1; count <= 16; count++) check_priority(mode, 3971 * count);
    $display("PASS");
  end
endmodule

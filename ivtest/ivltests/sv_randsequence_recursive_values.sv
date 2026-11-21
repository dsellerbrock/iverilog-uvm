// IEEE 1800-2017/2023 18.17.6 and 18.17.7.
module sv_randsequence_recursive_values;
  timeunit 1ns;
  timeprecision 1ns;

  localparam int WIDTH = 8;
  int actuals, defaults, step_weights, leaf_weights, current_depth;
  int index_evals;
  logic [59:0] depth_order = 0;

  function automatic int pass_depth(int depth);
    if (step_weights !== actuals || leaf_weights !== actuals)
      $fatal(1, "next actual evaluated before the previous choice");
    actuals++;
    current_depth = depth;
    depth_order = (depth_order << 4) | 60'(depth);
    return depth;
  endfunction

  function automatic int leaf_bias();
    defaults++;
    return 21; // The four-bit input captures 5.
  endfunction

  function automatic int branch_weight(int depth, bit is_step);
    if (depth !== current_depth || defaults !== actuals)
      $fatal(1, "weight evaluated before its production's inputs");
    if (is_step) begin
      if (++step_weights !== actuals) $fatal(1, "step weight evaluated twice");
      return depth > 0;
    end
    if (++leaf_weights !== actuals) $fatal(1, "leaf weight evaluated twice");
    return depth == 0;
  endfunction

  function automatic int generate_tree(int depth);
    int result;
    int copied = -1;
    randsequence (start)
      start : tree(.copied(copied), .n(pass_depth(depth)))
              { result = tree; };
      int tree(input int n, output int copied, input bit [3:0] bias = leaf_bias()) :
          tree(.n(pass_depth(n-1)), .copied(copied))
          { if (copied !== tree[1] + n - 1) $fatal(1, "first output copy-back"); }
          tree(pass_depth(n-1), copied)
          {
            if (copied !== tree[2] + n - 1) $fatal(1, "second output copy-back");
            copied = tree[1] + tree[2] + 2*n;
            return tree[1] + tree[2] + n;
          } := (branch_weight(n, 1))
        | { copied = bias - 4; return bias - 4; } := (branch_weight(n, 0));
    endsequence
    if (copied !== result + depth) $fatal(1, "output to function local");
    return result;
  endfunction

  task automatic check_slots();
    int repeat_actuals = 0;
    randsequence (start)
      start : slots(0) slots(1);
      slots(int selector) :
        if (selector) value(2) else value(3)
        case (selector)
          0: value(4);
          default: value(5);
        endcase
        repeat (3) value(repeat_actuals++)
        {
          if ($left(value) !== 1 || $right(value) !== 5)
            $fatal(1, "expected a 1:5 array of syntactic occurrences");
          if (selector == 0 && (value[2] !== 103 || value[3] !== 104 || value[5] !== 102))
            $fatal(1, "else, case or repeat result in the wrong slot");
          if (selector == 1 && (value[1] !== 102 || value[4] !== 105 || value[5] !== 105))
            $fatal(1, "if, default or repeat result in the wrong slot");
        };
      int value(int n) :
        if (n > 0) value(n-1)
        { if (n > 0) return value + 1; return 100; };
    endsequence
    if (repeat_actuals !== 6) $fatal(1, "repeat actual ran %0d times", repeat_actuals);
  endtask

  task automatic check_break();
    int visits, tails, completions;
    for (int pass = 0; pass < 2; pass++) begin
      visits = 0;
      tails = 0;
      completions = 0;
      randsequence (start)
        start : walk(3)
                { if (walk !== 10) $fatal(1, "normal return after reentry"); completions++; };
        int walk(int n) :
          { visits++; }
          if (n > 0) walk(n-1)
          {
            if (n == 0) begin
              if (pass == 0) break;
              return 7;
            end
            tails++;
            return walk + 1;
          };
      endsequence
      if (visits !== 4 || tails !== 3*pass || completions !== pass)
        $fatal(1, "sequence break did not unwind: pass=%0d visits=%0d tails=%0d completions=%0d",
               pass, visits, tails, completions);
    end
  endtask

  function automatic int output_index(int idx);
    index_evals++;
    return idx;
  endfunction

  task automatic check_timed_copy(int depth);
    logic signed [WIDTH-1:0] result, outs[0:3];
    int default_value = 21, copied_default = -1;
    time started = $time;
    randsequence (start)
      start : collect(depth) set_default;
      collect(int WIDTH) :
        timed(.n(WIDTH), .copied(outs[output_index(WIDTH)]))
        { if ($bits(timed) !== 8) $fatal(1, "return type bound in caller");
          result = timed; };
      logic signed [WIDTH-1:0] timed(input int n, output logic signed [WIDTH-1:0] copied) :
        { #1; }
        if (n > 0) timed(n-1, outs[output_index(n-1)])
        { copied = (n == 0) ? -9 : timed + 2; return copied; };
      set_default(input int default_value = default_value,
                  output int copied_default = copied_default) :
        { copied_default = default_value * 2; };
    endsequence
    for (int i = 0; i <= depth; i++)
      if (outs[i] !== -9 + 2*i) $fatal(1, "indexed output copy-back at %0d", i);
    if (result !== outs[depth] || copied_default !== 42 || $time !== started + depth + 1)
      $fatal(1, "timed typed recursion or declaration-scope default");
  endtask

  typedef int pair_t[0:1];
  task automatic check_array_results();
    randsequence (start)
      start : pair(2) pair(3)
              { if (pair[1][0] !== 12 || pair[1][1] !== 22 ||
                    pair[2][0] !== 13 || pair[2][1] !== 23)
                  $fatal(1, "repeated unpacked-array results"); };
      pair_t pair(int n) : if (n > 0) pair(n-1)
          { begin
              pair_t next_pair;
              if (n == 0) next_pair = '{10, 20};
              else next_pair = '{pair[0] + 1, pair[1] + 1};
              return next_pair;
            end };
    endsequence
  endtask

  initial begin
    if (generate_tree(3) !== 19) $fatal(1, "depth-three tree did not produce 19");
    if (actuals !== 15 || defaults !== 15 || step_weights !== 15 || leaf_weights !== 15
        || depth_order !== 60'h321001002100100)
      $fatal(1, "unexpected tree traversal or evaluation counts");
    check_slots();
    check_break();
    check_array_results();
    fork
      check_timed_copy(3);
      check_timed_copy(2);
    join
    if (index_evals !== 7) $fatal(1, "output index ran %0d times", index_evals);
    $display("PASS");
  end
endmodule

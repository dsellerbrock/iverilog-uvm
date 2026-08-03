`begin_keywords "1800-2012"

module main;
  logic [2:0] source;
  logic [1:0] index;
  logic [1:0] no_op_first;
  logic [1:0] no_op_last;
  logic [1:0] variable_first;
  logic [1:0] variable_last;

  // Concatenation elements are lowered through one shared output. A no-op or
  // run-time selected element must contribute no guaranteed bits without
  // erasing the whole-vector element, independent of element order.
  always_comb {no_op_first, no_op_first[9]} = source;
  always_comb {no_op_last[9], no_op_last} = source;
  always_comb {variable_first, variable_first[index]} = source;
  always_comb {variable_last[index], variable_last} = source;

  task automatic check(input logic [2:0] next_source,
                       input logic [1:0] next_index);
    source = next_source;
    index = next_index;
    #1;
    if (no_op_first !== source[2:1] || no_op_last !== source[1:0] ||
        variable_first !== source[2:1] || variable_last !== source[1:0]) begin
      $display("FAILED -- source=%b index=%b no_op=%b/%b variable=%b/%b",
               source, index, no_op_first, no_op_last,
               variable_first, variable_last);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(3'b101, 2'd3);
    check(3'b010, 2'bxx);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

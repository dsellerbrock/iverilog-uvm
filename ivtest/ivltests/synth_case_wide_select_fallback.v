`begin_keywords "1800-2012"

module main;
  logic [2:0] select;
  logic [2:0] empty_default_value;
  logic [2:0] implicit_default_value;

  // Ibex uses a 3-bit selector with explicit 0/1 clauses and an empty default.
  // The empty statement is still a real default clause: higher selector values
  // must take the pass-through value instead of being folded onto clause 1.
  always_comb begin
    empty_default_value = 3'd7;
    unique case (select)
      3'd0: empty_default_value = 3'd1;
      3'd1: empty_default_value = 3'd2;
      default: ;
    endcase
  end

  // The same fallback is implicit when no default clause is written.
  always_comb begin
    implicit_default_value = 3'd6;
    case (select)
      3'd0: implicit_default_value = 3'd3;
      3'd1: implicit_default_value = 3'd4;
    endcase
  end

  task automatic check(input logic [2:0] sel,
                       input logic [2:0] expected_empty,
                       input logic [2:0] expected_implicit);
    select = sel;
    #1;
    if (empty_default_value !== expected_empty ||
        implicit_default_value !== expected_implicit) begin
      $display("FAILED -- select=%0d empty=%0d implicit=%0d",
               select, empty_default_value, implicit_default_value);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(3'd0, 3'd1, 3'd3);
    check(3'd1, 3'd2, 3'd4);
    check(3'd2, 3'd7, 3'd6);
    check(3'd7, 3'd7, 3'd6);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

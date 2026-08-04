`begin_keywords "1800-2012"

module logic_observer(input logic [3:0] value);
endmodule

module main;
  logic       clk;
  logic       low_data;
  logic       high_data;
  logic       structural_data;
  logic [7:0] forward_order;
  logic [7:0] reverse_order;
  logic [0:7] ascending_order;
  bit   [3:0] two_state;
  logic [3:0] mixed_driver;

  // The two process orders prove that the initialization filler is attached
  // only after all exact ownership claims have been collected.
  always_ff @(posedge clk)
    forward_order[1] <= low_data;
  always_ff @(posedge clk)
    forward_order[6] <= high_data;

  always_ff @(posedge clk)
    reverse_order[6] <= high_data;
  always_ff @(posedge clk)
    reverse_order[1] <= low_data;

  // Canonical write masks are indexed by packed bit position, independent of
  // the source declaration direction.
  always_ff @(posedge clk)
    ascending_order[6] <= low_data;
  always_ff @(posedge clk)
    ascending_order[1] <= high_data;

  // Unwritten two-state variable bits initialize to zero, not X.
  always_ff @(posedge clk)
    two_state[2] <= high_data;

  // Child scopes are visited before their parent. This logic-typed alias must
  // not change the zero-initialization type recorded from the bit l-value.
  logic_observer observer(.value(two_state));

  // A pre-existing structural driver gives the packed object net semantics.
  // The final variable filler must therefore stay off every otherwise
  // undriven bit, which remains Z.
  assign mixed_driver[0] = structural_data;
  always_comb
    mixed_driver[2] = high_data;

  task tick;
    begin
      #1 clk = 1'b1;
      #1 clk = 1'b0;
    end
  endtask

  task fail(input string label);
    begin
      $display("FAILED -- %s forward=%b reverse=%b ascending=%b two=%b mixed=%b",
               label, forward_order, reverse_order, ascending_order,
               two_state, mixed_driver);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    low_data = 1'b0;
    high_data = 1'b1;
    structural_data = 1'b1;
    #1;
    if (forward_order !== 8'bxxxxxxxx ||
        reverse_order !== 8'bxxxxxxxx || ascending_order !== 8'bxxxxxxxx ||
        two_state !== 4'b0000 ||
        mixed_driver !== 4'bz1z1)
      fail("initial values");

    tick();
    if (forward_order !== 8'bx1xxxx0x ||
        reverse_order !== 8'bx1xxxx0x ||
        ascending_order !== 8'bx1xxxx0x || two_state !== 4'b0100 ||
        mixed_driver !== 4'bz1z1)
      fail("first clock");

    low_data = 1'b1;
    high_data = 1'b0;
    structural_data = 1'b0;
    tick();
    if (forward_order !== 8'bx0xxxx1x ||
        reverse_order !== 8'bx0xxxx1x ||
        ascending_order !== 8'bx0xxxx1x || two_state !== 4'b0000 ||
        mixed_driver !== 4'bz0z0)
      fail("second clock");

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

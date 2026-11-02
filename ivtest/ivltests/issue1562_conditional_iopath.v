`timescale 1ns/1ps

module issue1562_conditional_iopath_dut(
    input logic A, input logic mode, input logic other, output logic Y);
  assign Y = A;

  specify
    if (mode == 1'b1) (A => Y) = (0, 0);
    if (other) (A => Y) = (0, 0);
    ifnone (A => Y) = (0, 0);
  endspecify
endmodule

module issue1562_conditional_iopath;
  logic A = 0;
  logic mode = 1;
  logic other = 0;
  wire Y;
  integer transitions = 0;
  bit check_output = 0;

  issue1562_conditional_iopath_dut dut(A, mode, other, Y);

  initial begin
    $sdf_annotate("ivltests/issue1562_conditional_iopath.sdf", dut);

    #7 check_output = 1;
    #3 A = 1;
    #8 mode = 0;
    other = 1;
    #2 A = 0;
    #8 other = 0;
    #2 A = 1;
    #20 A = 0;
    #20;

    if (transitions != 4)
      $fatal(1, "expected 4 output transitions, got %0d", transitions);
    $display("PASSED");
    $finish;
  end

  always @(Y) begin
    if (check_output) begin
      case (transitions)
        0: if (Y !== 1 || $realtime != 14.0) $fatal(1, "mode path delay mismatch at %0t", $time);
        1: if (Y !== 0 || $realtime != 20.0) $fatal(1, "nonmatching condition was annotated at %0t", $time);
        2: if (Y !== 1 || $realtime != 37.0) $fatal(1, "CONDELSE rise delay mismatch at %0t", $time);
        3: if (Y !== 0 || $realtime != 58.0) $fatal(1, "CONDELSE fall delay mismatch at %0t", $time);
        default: $fatal(1, "unexpected output transition at %0t", $time);
      endcase
      transitions = transitions + 1;
    end
  end
endmodule

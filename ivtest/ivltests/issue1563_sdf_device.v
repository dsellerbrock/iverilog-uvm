`timescale 1ns/1ps

module issue1563_sdf_device_dut(
    input logic A, input logic B, input logic C, input logic D,
    output logic Y, output logic Z, output logic W);
  assign Y = A | B;
  assign Z = C;
  assign W = D;

  specify
    (A => Y) = 0;
    (B => Y) = 0;
    (C => Z) = 0;
    (D => W) = 0;
  endspecify
endmodule

module issue1563_sdf_device;
  logic A = 0;
  logic B = 0;
  logic C = 0;
  logic D = 0;
  wire Y;
  wire Z;
  wire W;
  integer y_transitions = 0;
  bit check_outputs = 0;

  issue1563_sdf_device_dut u(A, B, C, D, Y, Z, W);

  initial begin
    $sdf_annotate("ivltests/issue1563_sdf_device.sdf");

    #9 check_outputs = 1;
    #1 A = 1;
    #12 A = 0;
    #7 B = 1;
    #11 C = 1;
    #10 D = 1;
    #4;

    if (y_transitions != 3)
      $fatal(1, "expected three DEVICE-delayed Y transitions, got %0d", y_transitions);
    if (Z !== 1)
      $fatal(1, "expected DEVICE-delayed Z rise");
    if (W !== 1)
      $fatal(1, "expected unqualified DEVICE-delayed W rise");
    $display("PASSED");
    $finish;
  end

  always @(Y) begin
    if (check_outputs) begin
      case (y_transitions)
        0: if (Y !== 1 || $realtime != 14.0) $fatal(1, "first Y path delay mismatch at %0t", $time);
        1: if (Y !== 0 || $realtime != 28.0) $fatal(1, "Y fall delay mismatch at %0t", $time);
        2: if (Y !== 1 || $realtime != 33.0) $fatal(1, "second Y path delay mismatch at %0t", $time);
        default: $fatal(1, "unexpected Y transition at %0t", $time);
      endcase
      y_transitions = y_transitions + 1;
    end
  end

  always @(Z) begin
    if (check_outputs && Z !== 1)
      $fatal(1, "unexpected Z transition at %0t", $time);
    if (check_outputs && $realtime != 43.0)
      $fatal(1, "single-value Z delay mismatch at %0t", $time);
  end

  always @(W) begin
    if (check_outputs && W !== 1)
      $fatal(1, "unexpected W transition at %0t", $time);
    if (check_outputs && $realtime != 52.0)
      $fatal(1, "unqualified DEVICE delay mismatch at %0t", $time);
  end
endmodule

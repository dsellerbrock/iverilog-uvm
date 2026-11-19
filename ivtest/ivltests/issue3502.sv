`timescale 1ns/1ns
module issue3502;
  logic one = 1, zero = 0, procedural;
  bit equal_default = 0;
  logic [3:0] packed_src = 4'b01xz, active_src = 4'b1z0x;
  string text = "first", text_out;

  wire w_one, w_zero, w_bit, w_not, w_proc, w_const, w_gate, w_pull, w_off;
  logic var_out;
  wire [3:0] w_packed, w_active;
  wire [3:0] w_decl = 4'd5;

  assign w_one = one;
  assign w_zero = zero;
  assign w_bit = equal_default;
  assign var_out = one;
  assign w_packed = packed_src;
  assign w_active = active_src;
  assign w_not = ~one;
  assign w_proc = procedural;
  assign w_const = 1'b1;
  assign text_out = text;
  buf (w_gate, one);
  pullup (w_pull);
  bufif1 (w_off, 1'b0, 1'b0);
  pullup (w_off);

  bit [31:0] hits [0:11][0:2];
  bit [31:0] rises, falls, string_hits;

  task automatic observe(input int idx, input logic [3:0] actual,
                         input logic [3:0] at_zero, at_one = 'x, at_two = 'x);
    logic [3:0] expected;
    case ($time)
      0: expected = at_zero;
      1: expected = at_one;
      2: expected = at_two;
      default: $fatal(1, "unexpected target %0d event at %0t", idx, $time);
    endcase
    if (actual !== expected)
      $fatal(1, "target %0d at %0t: got %b, expected %b", idx, $time, actual, expected);
    hits[idx][$time]++;
  endtask

  always @(w_one)   observe( 0, w_one,   1, 0);
  always @(w_zero)  observe( 1, w_zero,  0, 1);
  always @(w_bit)   observe( 2, w_bit,   0, 1);
  always @(var_out) observe( 3, var_out, 1, 0);
  always @(w_packed) observe(4, w_packed, 4'b01xz, 4'bz101, 4'bzx01);
  always @(w_not)   observe( 5, w_not,   0, 1);
  always @(w_proc)  observe( 6, w_proc,  1, 0);
  always @(w_gate)  observe( 7, w_gate,  1, 0);
  always @(w_const) observe( 8, w_const, 1);
  always @(w_decl)  observe( 9, w_decl,  5);
  always @(w_pull)  observe(10, w_pull,  1);
  always @(w_off)   observe(11, w_off,   1);
  always @(posedge w_one) begin
    if ($time != 0 || w_one !== 1'b1) $fatal(1, "unexpected positive edge");
    rises++;
  end
  always @(negedge w_zero) begin
    if ($time != 0 || w_zero !== 1'b0) $fatal(1, "unexpected negative edge");
    falls++;
  end
  always @(text_out) begin
    if (!(($time == 0 && text_out == "first") || ($time == 1 && text_out == "second")))
      $fatal(1, "unexpected string event at %0t", $time);
    string_hits++;
  end

  task automatic check_counts(input int tick, input int first_targets);
    for (int idx = 0; idx < 12; idx++) begin
      int expected;
      expected = (tick == 2) ? (idx == 4) : (idx < first_targets);
      if (hits[idx][tick] != expected)
        $fatal(1, "target %0d at time %0d: got %0d events, expected %0d",
               idx, tick, hits[idx][tick], expected);
    end
  endtask

  initial begin
    if ({one, zero, equal_default, packed_src, active_src} !== 11'b100_01xz_1z0x)
      $fatal(1, "static variables were not initialized before process entry");

    procedural = 1;
    active_src[3:2] = 2'bz0;
    active_src[0] = 1;
    #0;
    if (w_active !== 4'bz001)
      $fatal(1, "stale time-zero delivery: %b", w_active);

    #1;
    check_counts(0, 12);
    if (rises != 1 || falls != 1 || string_hits != 1)
      $fatal(1, "time-zero edges or string event missing or duplicated");
    one = 0;
    zero = 1;
    equal_default = 1;
    packed_src = 4'bz101;
    procedural = 0;
    text = "second";

    #1;
    check_counts(1, 8);
    packed_src[2:1] = 2'bx0;

    #1;
    check_counts(2, 0);
    if (string_hits != 2) $fatal(1, "wrong string event count");
    $display("PASSED");
    $finish(0);
  end
endmodule

// VPI-only top. Both runners select it explicitly.
`timescale 1ns/1ns
module top;
  logic source = 1'b1;
  logic clamp = 1'b1;
  wire observed;
  assign (weak1, weak0) observed = source;
  assign (weak1, strong0) observed = clamp;

  initial begin
    #1 clamp = 1'bz;
    #1 clamp = 1;
    #1 source = 1'bz;
    #1 clamp = 0;
    #1 $finish(0);
  end
endmodule

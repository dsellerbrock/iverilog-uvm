// An unpacked-array concatenation with a dynamic-array operand is valid in
// a conditional arm (IEEE 1800-2017/2023 10.10, 11.4.11). OpenTitan's
// kmac_scoreboard builds its message with
//   masked_data = endian ? {full_data[i], masked_data} : {masked_data, full_data[i]};
// The darray literal was pre-sized, so the operand became one default
// element.
module test;
  bit [7:0] full_data[4] = '{174, 39, 213, 153};
  bit [7:0] a[], c[], r[];
  bit [7:0] exp_a[] = '{153, 213, 39, 174};
  bit [7:0] exp_c[] = '{174, 39, 213, 153};
  bit [7:0] exp_r[] = '{9, 153, 213, 39, 174, 9};
  bit [7:0] x = 9;
  bit sel = 1;
  bit ok = 1;
  initial begin
    for (int i = 0; i < 4; i++) begin
      a = sel ? {full_data[i], a} : {a, full_data[i]};
      c = !sel ? {full_data[i], c} : {c, full_data[i]};
    end
    r = sel ? {x, a, x} : a;
    if (a != exp_a) begin $display("FAILED: a=%p", a); ok = 0; end
    if (c != exp_c) begin $display("FAILED: c=%p", c); ok = 0; end
    if (r != exp_r) begin $display("FAILED: r=%p", r); ok = 0; end
    if (ok) $display("PASSED");
  end
endmodule

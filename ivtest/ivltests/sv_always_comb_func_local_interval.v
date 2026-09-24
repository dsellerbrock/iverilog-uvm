package sv_always_comb_func_local_interval_pkg;
  function automatic logic [7:0] mul2(input logic [7:0] x);
    logic [7:0] out;
    out[7] = x[6];
    out[6] = x[5];
    out[5] = x[4];
    out[4] = x[3] ^ x[7];
    out[3] = x[2] ^ x[7];
    out[2] = x[1];
    out[1] = x[0] ^ x[7];
    out[0] = x[7];
    return out;
  endfunction
endpackage

module sv_always_comb_func_local_interval_cell(
  input logic [7:0] x, output logic [7:0] y
);
  import sv_always_comb_func_local_interval_pkg::*;
  always_comb y = mul2(x);
endmodule

module sv_always_comb_func_local_interval;
  logic [7:0] a, b, ya, yb;
  logic [7:0] source;
  logic [7:0] partial;
  logic boundary_y;

  sv_always_comb_func_local_interval_cell first_cell(a, ya);
  sv_always_comb_func_local_interval_cell second_cell(b, yb);

  // An unrelated source bit must remain in the implicit sensitivity set.
  always_comb begin
    partial[7:1] = source[7:1];
    boundary_y = source[0] ^ partial[7];
  end

  initial begin
    a = 8'h01;
    b = 8'h02;
    source = 8'h00;
    #1;
    if (ya !== 8'h02 || yb !== 8'h04)
      $fatal(1, "function outputs wrong: %h %h", ya, yb);
    if (boundary_y !== 1'b0)
      $fatal(1, "initial boundary result wrong");
    source[0] = 1'b1;
    #1;
    if (boundary_y !== 1'b1)
      $fatal(1, "unwritten source read was lost from sensitivity");
    $display("PASSED");
  end
endmodule

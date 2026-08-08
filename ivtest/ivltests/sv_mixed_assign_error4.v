// Check vector part cannot be both procedurally and continuously assigned.
module test();

logic [7:0] v;

assign v[5:2] = 4'd0;

integer lsb = 0;
integer msb = 7;

initial begin
  v[1:0] = 2'd1;
  v[3:2] = 2'd1;
  v[5:4] = 2'd1;
  v[7:6] = 2'd1;

  v[0 +: 2] = 2'd2;
  v[2 +: 2] = 2'd2;
  v[5 -: 2] = 2'd2;
  v[7 -: 2] = 2'd2;

  v[lsb +: 2] = 2'd3;
  v[msb -: 2] = 2'd3;

  v[0] = 1'b1;
  v[2] = 1'b1;
  v[4] = 1'b1;
  v[6] = 1'b1;

  v[lsb] = 1'b1;
  v[msb] = 1'b1;
end

endmodule

// The multidimensional companion: outer slice [3:1] includes element 1,
// so it must still conflict with a continuous driver on that element after
// both selections are converted to the signal's flattened bit numbering.
module test_multidim;
  logic clk;
  logic [3:0][6:0] m;
  assign m[1] = 7'h00;
  always_ff @(posedge clk)
    m[3:1] <= '0;
endmodule

module issue2461_leaf(input [1:0] d, input e, output [1:0] q, output t);
  assign q = ~d;
  assign t = e ? d[0] : 1'bz;
endmodule

module issue2461_dumpports_shared_vector;
  reg [1:0] d = 1;
  reg e = 1;
  wire [1:0] q;
  wire t;

  issue2461_leaf u (d, e, q, t);

  initial begin
    $dumpports(u, "work/issue2461_dumpports_shared_vector.evcd");
    #1 d = 2;
    #1 $display("PASSED");
  end
endmodule

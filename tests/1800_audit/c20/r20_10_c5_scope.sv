module leaf; initial $info("rt info"); endmodule
module top; leaf u1(); generate begin : G leaf u2(); end endgenerate endmodule

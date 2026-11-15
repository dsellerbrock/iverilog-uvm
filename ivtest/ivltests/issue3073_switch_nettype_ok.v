// IEEE 1800-2023 28.8: tran, tranif1 and tranif0 may connect nets of the
// same user-defined net type (an alias names the same net type), and every
// switch still connects built-in nets.
module top;
  function automatic logic resolve(input logic drivers[]);
    return drivers.size() ? drivers[0] : 1'bz;
  endfunction
  nettype logic nt with resolve;
  nettype nt nt_alias;
  nt a, a2;
  nt_alias a3;
  wire b, c, en;
  tran t1(a, a2);
  tran t2(a2, a3);
  tranif1 t3(a, a3, en);
  tran t4(b, c);
  rtran t5(b, c);
  initial $display("PASSED");
endmodule

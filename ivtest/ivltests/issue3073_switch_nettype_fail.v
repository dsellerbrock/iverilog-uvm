// IEEE 1800-2023 28.8: a bidirectional switch may not connect nets of two
// different user-defined net types, or a user-defined net type and a
// built-in net type; the rtran switches connect built-in nets only.
// 1800-2017 has no such rule: -g2017 keeps accepting these connections.
module top;
  function automatic logic resolve(input logic drivers[]);
    return drivers.size() ? drivers[0] : 1'bz;
  endfunction
  nettype logic nt with resolve;
  nettype logic other_nt with resolve;
  nt a, a2;
  other_nt o;
  wire b, c;
  tran t1(a, b);          // user-defined to built-in
  tran t2(a, o);          // two different user-defined net types
  tranif1 t3(b, a, c);    // built-in to user-defined
  rtran t4(a, a2);        // rtran cannot connect user-defined net types
  initial $display("PASSED");
endmodule

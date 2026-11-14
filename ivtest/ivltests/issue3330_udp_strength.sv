`timescale 1ns/1ns
primitive inv(output o, input a);
  table 0 : 1; 1 : 0; endtable
endprimitive
module top;
  reg a = 0;
  wire x, y, z, delayed, resolved, hiz, plain, plain2;
  wire [1:0] array_out, array_resolved;
  inv (strong0, weak1) u(x, a), v(y, a);
  inv (weak1, strong0) (z, a);
  inv (plain, a), (plain2, a);
  inv (pull0, weak1) #(2, 3) d(delayed, a);
  inv (strong0, weak1) uarr[1:0](array_out, a);
  inv (strong0, weak1) rarr[1:0](array_resolved, a);
  assign (pull0, pull1) array_resolved[0] = 0;
  assign (pull0, pull1) array_resolved[1] = 0;
  inv (strong0, weak1) r(resolved, a);
  inv (highz0, weak1) h(hiz, a);
  assign (pull0, pull1) resolved = 0;
  initial begin
    #4;
    if ($sformatf("%v %v", plain, plain2) != "St1 St1")
      $fatal(1, "wrong anonymous UDP output: %v %v", plain, plain2);
    if ($sformatf("%v", hiz) != "We1") $fatal(1, "wrong highz strength: %v", hiz);
    if ($sformatf("%v %v", array_resolved[0], array_resolved[1]) != "Pu0 Pu0")
      $fatal(1, "wrong array resolution: %v %v", array_resolved[0], array_resolved[1]);
    if ($sformatf("%v %v %v %v %v %v %v", x, y, z, delayed,
                  array_out[0], array_out[1], resolved) !=
        "We1 We1 We1 We1 We1 We1 Pu0") $fatal(1, "wrong strengths for input 0: %v %v %v %v %v %v %v", x, y, z, delayed, array_out[0], array_out[1], resolved);
    a = 1;
    #2;
    if ($sformatf("%v", hiz) != "HiZ") $fatal(1, "wrong highz output: %v", hiz);
    if ($sformatf("%v", delayed) != "We1") $fatal(1, "fall delay lost: %v", delayed);
    #2;
    if ($sformatf("%v %v %v %v %v %v %v", x, y, z, delayed,
                  array_out[0], array_out[1], resolved) !=
        "St0 St0 St0 Pu0 St0 St0 St0") $fatal(1, "wrong strengths for input 1: %v %v %v %v %v %v %v", x, y, z, delayed, array_out[0], array_out[1], resolved);
    $display("PASS");
  end
endmodule

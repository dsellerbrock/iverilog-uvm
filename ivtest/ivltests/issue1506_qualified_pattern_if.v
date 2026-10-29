typedef union tagged { void Invalid; int Valid; } VInt;
module test;
  VInt v;
  initial begin
    v = tagged Valid(5);
    unique if (v matches tagged Invalid) $display("unexpected unique");
    priority if (v matches tagged Invalid) $display("unexpected priority");
    $display("PASSED");
  end
endmodule

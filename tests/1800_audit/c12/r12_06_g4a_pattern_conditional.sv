typedef union tagged {void Invalid; int Valid;} VInt;
module r12_06_g4a_pattern_conditional;
  VInt v;
  int hit;
  initial begin
    v = tagged Valid(5);
    hit = v matches tagged Valid .n ? n : -1;
    $display("g4a hit=%0d", hit);
  end
endmodule

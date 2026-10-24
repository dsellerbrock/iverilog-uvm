typedef union tagged {void Invalid; int Valid;} VInt;
module r12_06_g4b_guarded_pattern_conditional;
  VInt v;
  int hit;
  initial begin
    v = tagged Valid(5);
    hit = v matches tagged Valid .n &&& n > 3 ? n : -1;
    $display("g4b hit=%0d", hit);
  end
endmodule

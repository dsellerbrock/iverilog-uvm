module r12_06_g4c_guarded_expression_conditional;
  int y = 1;
  int hit;
  initial begin
    hit = y &&& (y > 0) ? 5 : -1;
    $display("g4c hit=%0d", hit);
  end
endmodule

module pla_output_net_fail;
  logic [1:1] mem [1:1];
  logic a;
  wire y;
  initial begin
    mem[1] = 1'b1;
    a = 1'b1;
    $async$and$array(mem, a, y);
  end
endmodule

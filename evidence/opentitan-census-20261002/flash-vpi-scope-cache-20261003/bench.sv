module leaf;
  reg status;
  initial status = 1'b1;
endmodule

module top;
  genvar i;
  for (i = 0; i < 1024; i = i + 1) begin : g
    leaf u_leaf();
  end
  initial begin
    $scope_cache_bench;
    $finish;
  end
endmodule

module issue1261_leaf;
endmodule

module issue1261_module_array_vpi_index;
  issue1261_leaf inst[2:4]();
  issue1261_leaf plain();

  initial begin
    #0;
    $check_module_array_indices;
    $finish;
  end
endmodule

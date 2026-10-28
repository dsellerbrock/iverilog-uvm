interface issue1262_bus;
  logic x;
endinterface

module issue1262_interface_index;
  issue1262_bus arr[1:0]();
  issue1262_bus scalar();

  initial begin
    #0;
    $probe_interface_index;
    $finish;
  end
endmodule

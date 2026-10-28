interface issue1269_bus;
  logic x;
endinterface

module issue1269_vpi_virtual_interface_iter;
  issue1269_bus b();
  virtual interface issue1269_bus vi;
  virtual interface issue1269_bus arr[1:0];

  initial begin
    vi = b;
    arr[0] = b;
    arr[1] = b;
    #0;
    $probe_vif_iter;
    $finish;
  end
endmodule

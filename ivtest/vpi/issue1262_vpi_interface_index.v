interface bus;
  logic x;
endinterface

module top;
  bus arr[1:0]();
  bus scalar();
  bus \arr[7] ();

  initial begin
    #0;
    $probe_interface_index;
    $finish;
  end
endmodule

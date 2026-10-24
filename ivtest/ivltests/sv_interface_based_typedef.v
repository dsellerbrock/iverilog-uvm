// Interface-based typedef references are locally redefined through a port
// (IEEE 1800-2017/2023 6.18).
interface interface_based_typedef_if;
  typedef logic [7:0] data_t;
endinterface

module interface_based_typedef_sub(interface_based_typedef_if p);
  typedef p.data_t my_data_t;
  my_data_t data;

  initial begin
    if ($bits(data) != 8)
      $fatal(1, "$bits(data)=%0d, expected 8", $bits(data));
    $display("PASSED");
  end
endmodule

module sv_interface_based_typedef;
  interface_based_typedef_if intf();
  interface_based_typedef_sub sub(intf);
endmodule

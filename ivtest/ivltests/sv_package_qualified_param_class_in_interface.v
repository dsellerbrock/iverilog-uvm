package proxy_types_pkg;
  class proxy #(parameter int WIDTH = 32);
    logic [WIDTH-1:0] payload;
  endclass
endpackage

interface proxy_bfm #(parameter int WIDTH = 32);
  proxy_types_pkg::proxy #(.WIDTH(WIDTH)) proxy_handle;
endinterface

module sv_package_qualified_param_class_in_interface;
  proxy_bfm #(.WIDTH(8)) bfm();

  initial begin
    bfm.proxy_handle = new;
    if ($bits(bfm.proxy_handle.payload) != 8)
      $fatal(1, "package-qualified class handle lost its parameter override");
    bfm.proxy_handle.payload = 8'hA5;
    if (bfm.proxy_handle.payload != 8'hA5)
      $fatal(1, "package-qualified parameterized class handle has wrong width");
    $display("PASSED");
  end
endmodule

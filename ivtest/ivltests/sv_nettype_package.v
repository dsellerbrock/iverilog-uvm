package sv_nettype_package_types;
  nettype logic [15:0] word_net;
endpackage

module sv_nettype_package;
  import sv_nettype_package_types::*;
  nettype sv_nettype_package_types::word_net qualified_alias;
  word_net data;
  qualified_alias qualified_data;

  initial begin
    if ($bits(data) != 16 || $bits(qualified_data) != 16)
      $fatal(1, "package nettype width mismatch");
    $display("PASSED");
  end
endmodule

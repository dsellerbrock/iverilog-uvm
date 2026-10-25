class invalid_class_nettype_resolver;
  function automatic logic [7:0] instance_method(input logic [7:0] drivers[]);
    instance_method = drivers.size() ? drivers[0] : 0;
  endfunction

  static function automatic logic [7:0] wrong_signature(input logic [3:0] drivers[]);
    wrong_signature = drivers.size() ? {4'b0, drivers[0]} : 0;
  endfunction
endclass

nettype logic [7:0] nonstatic_resolver_net with invalid_class_nettype_resolver::instance_method;
nettype logic [7:0] wrong_signature_net with invalid_class_nettype_resolver::wrong_signature;

module sv_nettype_class_resolver_invalid;
  nonstatic_resolver_net n1;
  wrong_signature_net n2;
endmodule

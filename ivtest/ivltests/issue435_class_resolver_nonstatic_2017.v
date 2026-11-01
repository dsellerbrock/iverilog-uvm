class issue435_nonstatic_resolver;
  function logic resolve(input logic drivers[]);
    logic value;
    value = 1'b0;
    foreach (drivers[i]) value |= drivers[i];
    return value;
  endfunction
endclass

nettype logic issue435_bad_net with issue435_nonstatic_resolver::resolve;
module issue435_class_resolver_nonstatic;
  issue435_bad_net net;
endmodule

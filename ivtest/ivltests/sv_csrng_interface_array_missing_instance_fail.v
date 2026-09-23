interface csrng_missing_instance_if;
  logic member;
endinterface

module sv_csrng_interface_array_missing_instance_fail;
  wire observed;
  assign observed = csrng_missing_instance_if[0].member;
endmodule

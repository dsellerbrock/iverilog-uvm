interface csrng_missing_member_if;
  logic present;
endinterface

module sv_csrng_interface_array_missing_member_fail;
  wire observed;
  csrng_missing_member_if csrng_missing_member_if[2]();
  assign observed = csrng_missing_member_if[0].absent;
endmodule

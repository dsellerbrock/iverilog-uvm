interface csrng_scalar_same_if;
  wire member = 1'b1;
endinterface

module sv_csrng_interface_scalar_same_name;
  wire observed;
  csrng_scalar_same_if csrng_scalar_same_if();
  assign observed = csrng_scalar_same_if.member;
  initial begin
    #1;
    if (observed !== 1'b1) $fatal(1, "scalar same-name interface broke");
    $display("PASSED");
    $finish(0);
  end
endmodule

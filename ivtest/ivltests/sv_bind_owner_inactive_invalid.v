// IEEE 1800-2017/2023 23.11/27.5: a bind directive whose owner scope is not
// elaborated does not exist. Neither an excluded module nor an inactive
// generate arm may diagnose its otherwise-invalid target.
module sv_bind_owner_inactive_invalid_probe;
endmodule

module sv_bind_owner_inactive_invalid_excluded;
  bind missing_target sv_bind_owner_inactive_invalid_probe excluded_p();
endmodule

module sv_bind_owner_inactive_invalid;
  if (0) begin : inactive
    bind missing_target sv_bind_owner_inactive_invalid_probe inactive_p();
  end

  initial begin
    #1;
    $display("PASSED");
  end
endmodule

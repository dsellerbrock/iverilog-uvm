module r06_24b_real_assign_control;
  real rv;
  initial begin
    rv = 7;
    $display("CONTROL rv=%f", rv);
  end
endmodule

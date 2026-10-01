module otp_inside_endpoint_typed;
  class cfg;
    localparam bit [31:0] TimeoutMax = '1;
    rand bit [31:0] check_timeout_val;
    constraint timeout_c { check_timeout_val inside {0, [100_000:TimeoutMax]}; }
  endclass
  cfg item;
  initial begin
    item = new;
    repeat (10) begin
      if (!item.randomize()) $fatal(1, "randomize failed");
      if (item.check_timeout_val != 0 && item.check_timeout_val < 100_000)
        $fatal(1, "out-of-range value %d", item.check_timeout_val);
    end
    if (!item.randomize() with { check_timeout_val == 32'hffff_ffff; })
      $fatal(1, "upper endpoint missing");
    if (item.randomize() with { check_timeout_val == 32'd99_999; })
      $fatal(1, "hole below range was accepted");
    $display("PASS typed inside endpoint");
    $finish;
  end
endmodule

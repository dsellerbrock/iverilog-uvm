module otp_inside_endpoint_red;
  class cfg;
    rand bit [31:0] check_timeout_val;
    constraint timeout_c { check_timeout_val inside {0, [100_000:'1]}; }
  endclass
  cfg item;
  initial begin
    item = new;
    if (!item.randomize()) $fatal(1, "randomize failed");
    $finish;
  end
endmodule

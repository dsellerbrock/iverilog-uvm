module top;
  class wide_scalar_case;
    rand int unsigned delay_value;
    rand bit parity;

    constraint parity_c { parity == delay_value[0]; }
    constraint delay_soft_c { soft delay_value inside {[0:50]}; }
  endclass

  initial begin
    wide_scalar_case item;
    item = new;
    for (int i = 0; i < 8; i++) begin
      if (!item.randomize()) $fatal(1, "wide_scalar randomize failed");
      if (item.delay_value > 50 || item.parity != item.delay_value[0])
        $fatal(1, "wide_scalar constraint violation");
    end
    $display("PASS wide_scalar");
    $finish;
  end
endmodule

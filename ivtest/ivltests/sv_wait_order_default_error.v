module sv_wait_order_default_error;
  event expected, later;

  initial begin
    fork
      begin
        #1;
        -> later;
        -> expected;
      end
      begin
        wait_order(expected, later);
      end
    join
  end
endmodule

module sv_wait_order_null_else;
  event first, second;

  initial begin
    fork
      begin
        #1;
        -> first;
        -> second;
      end
      begin
        wait_order(first, second) ; else ;
      end
    join
  end
endmodule

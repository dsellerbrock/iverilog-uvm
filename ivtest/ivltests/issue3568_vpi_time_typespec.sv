module top;
  time plain;
  typedef time my_time;
  typedef my_time other_time;
  my_time named_time;
  other_time chained_time;
  initial begin
    plain = 0; named_time = 0; chained_time = 0;
    #1 $check_time_typespec;
  end
endmodule

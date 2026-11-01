module top;
  time tt;
  integer ii;
  real rr;
  reg [63:0] rv;

  initial begin
    $issue955_check_types(tt, ii, rr, rv);
    #1 $finish;
  end
endmodule

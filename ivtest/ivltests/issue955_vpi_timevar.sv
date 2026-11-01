module top;
  time tt;
  integer ii;
  reg rr;

  initial begin
    tt = 1;
    ii = 2;
    rr = 1'b1;
    #1 $finish;
  end
endmodule

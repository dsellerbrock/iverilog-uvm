package P;
  typedef struct { real field1; bit field2; } T;
  function automatic T Tsum(input T driver[]);
    Tsum.field1 = 0.0;
    foreach (driver[i])
      Tsum.field1 += driver[i].field1;
  endfunction
  nettype T wTsum with Tsum;
  nettype wTsum nettypeid2;
endpackage
module top;
  import P::*;
  wTsum n;
  assign n = '{1.5, 1'b1};
  assign n = '{2.0, 1'b0};
  initial begin
    #1 $display("resolved %0.1f", n.field1);

  end
endmodule

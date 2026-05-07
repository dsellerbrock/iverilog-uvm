// G46: union tagged with void member syntax (IEEE 1800-2017 §6.13)
module top;
  typedef union tagged {
    void Inv;
    int  Num;
  } TagU;

  initial begin
    TagU x;
    x = tagged Num 42;
    $display("PROBE_OK_tagged_void");
    $finish;
  end
endmodule

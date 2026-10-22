module test;
  typedef union tagged {
    int ival;
    logic [7:0] bval;
    void empty;
  } tagged_union_t;

  tagged_union_t value;

  initial begin
    value = tagged ival 42;
    if (value.ival != 42)
      $fatal(1, "tagged union integer constructor/member mismatch");

    value = tagged bval 8'ha5;
    if (value.bval !== 8'ha5)
      $fatal(1, "tagged union byte constructor/member mismatch");

    value = tagged empty;
    $display("PASS §7.3.2 tagged union constructors");
    $finish;
  end
endmodule

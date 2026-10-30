module top;
  integer ia[1:0];
  time ta[1:0];
  real ra[1:0];

  initial begin
    ia[0] = 1;
    ta[0] = 2;
    ra[0] = 3.0;
    #0;
    $probe_regarray_iteration;
    $finish;
  end
endmodule

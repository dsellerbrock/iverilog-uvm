module test;
  int a = 1, h = 0, c = 0;
  int y, z, n, nested;
  real r = 1.5;
  wire real rr, rr_arg;
  function automatic int f(input int x); return x + h; endfunction
  function automatic int g(); return a + h; endfunction
  function automatic int inner(); return h; endfunction
  function automatic int outer(); return inner() + 3; endfunction
  function automatic real rf(); return r + 0.5; endfunction
  function automatic real rfa(input real x); return x + r; endfunction
  assign y = f(a);
  assign z = g();
  assign n = f(a) + c;
  assign nested = outer();
  assign rr = rf();
  assign rr_arg = rfa(2.0);
  task check(input int ey, ez, en, et, input real er);
    if (y !== ey || z !== ez || n !== en || nested !== et || rr != er ||
        rr_arg != er + 1.5)
      $fatal(1, "got %0d %0d %0d %0d %f expected %0d %0d %0d %0d %f",
             y, z, n, nested, rr, ey, ez, en, et, er);
  endtask
  initial begin
    #1; check(1, 1, 1, 3, 2.0);
    h = 10; r = 3.0;
    #1; check(11, 11, 11, 13, 3.5);
    a = 2;
    #1; check(12, 12, 12, 13, 3.5);
    c = 5;
    #1; check(12, 12, 17, 13, 3.5);
    $display("PASS function reads in continuous assignments");
  end
endmodule

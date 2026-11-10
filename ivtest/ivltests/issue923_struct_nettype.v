// IEEE 1800-2017/2023 6.6.7, 6.7.3: nets of a user-defined nettype whose
// data type is an unpacked struct, with and without a resolution function.
module top;
  typedef struct { real field1; bit field2; } T;

  // The 6.6.7 example resolver.
  function automatic T Tsum (input T driver[]);
    Tsum.field1 = 0.0;
    foreach (driver[i]) Tsum.field1 += driver[i].field1;
  endfunction

  nettype T wTsum with Tsum;
  typedef struct { int a = 5; logic [1:0] b; } st_t;
  nettype st_t ns;                // unresolved

  T d1, d2;
  wTsum w;                        // two drivers
  wTsum none;                     // no driver: Tsum('{}) at time zero
  assign w = d1;
  assign w = d2;

  st_t v = '{3, 2'b01};
  ns u;                           // undriven: member initializers apply
  ns n;                           // one driver
  assign n = v;

  initial begin
    d1.field1 = 1.5;
    d2.field1 = 2.0;
    #1;
    if (w.field1 != 3.5 || none.field1 != 0.0) $display("FAILED w=%0.1f none=%0.1f", w.field1, none.field1);
    if (u.a !== 5 || u.b !== 2'bxx) $display("FAILED u.a=%0d u.b=%b", u.a, u.b);
    if (n.a !== 3 || n.b !== 2'b01) $display("FAILED n.a=%0d n.b=%b", n.a, n.b);
    d2.field1 = 4.0;
    v = '{7, 2'b10};
    #1;
    if (w.field1 != 5.5) $display("FAILED w=%0.1f", w.field1);
    if (n.a !== 7 || n.b !== 2'b10) $display("FAILED n.a=%0d n.b=%b", n.a, n.b);
    $display("PASSED");
  end
endmodule

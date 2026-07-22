// Per-element assignment of a static (fixed-size) unpacked array of an
// UNPACKED struct. This used to silently miscompile (the struct r-value
// degraded to a null store, so the element was left null and later reads
// and %p aborted at run time); it was then diagnosed with a `sorry`. The
// element write now lowers correctly: `arr[i] = '{...}` builds the struct
// object and stores it into the indexed element, so the whole-element
// pattern assign, a struct-variable assign, and an element-to-element copy
// all work, and member reads of the assigned element read back the stored
// values. (IEEE 1800-2017 7.2.1.) Member WRITES `arr[i].field = x` on an
// element that has not been whole-assigned still need element
// auto-construction and remain diagnosed separately.
module sv_ustruct_array_element;
  typedef struct { int a; int b; } P;   // unpacked struct
  P arr[3];
  P s;
  int errors = 0;

  initial begin
    // whole-element pattern assign
    arr[0] = '{a:1, b:2};
    // struct-variable assign into an element
    s = '{a:3, b:4};
    arr[1] = s;
    // element-to-element copy
    arr[2] = arr[0];

    if (arr[0].a != 1 || arr[0].b != 2) begin
      $display("FAIL arr[0]=(%0d,%0d)", arr[0].a, arr[0].b); errors++; end
    if (arr[1].a != 3 || arr[1].b != 4) begin
      $display("FAIL arr[1]=(%0d,%0d)", arr[1].a, arr[1].b); errors++; end
    if (arr[2].a != 1 || arr[2].b != 2) begin
      $display("FAIL arr[2]=(%0d,%0d)", arr[2].a, arr[2].b); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule

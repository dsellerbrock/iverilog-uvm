// M4C-5: (1) reading a member of a NONEXISTENT associative-array key yields
// the 4-state default x (2-state default 0) and does NOT create the entry
// (IEEE 1800-2017 7.8.6, 7.9.11); (2) a bit/part/indexed select on a
// dynamic-array/queue ELEMENT (q[i][m:l], d[i][b +: w]) selects within the
// element — formerly the [m:l] form silently returned the WHOLE element and
// [b -: w] was mis-based; (3) an unpacked-array property read through a
// nested handle chain (o.inr.arr[i]) returns the written element — formerly
// the element index was dropped on the read (whole-array %prop/v) and the
// read returned x. Self-checking.
module sv_container_elem_read_defaults;
  typedef struct { logic [7:0] lv; bit [7:0] bv; } s_t;
  class Inner; int arr[4]; endclass
  class Outer; Inner inr; function new(); inr = new; endfunction endclass
  s_t m[string];
  logic [15:0] q[$];
  int d[];
  int errors = 0;
  initial begin
    automatic Outer o = new;

    // (1) missing-key member defaults; read must not insert.
    if (m["never"].lv !== 8'hxx) begin $display("FAIL lv=%h exp xx", m["never"].lv); errors++; end
    if (m["never"].bv !== 8'h00) begin $display("FAIL bv=%h exp 00", m["never"].bv); errors++; end
    if (m.num() !== 0) begin $display("FAIL read created entry"); errors++; end

    // (2) queue/darray element tail selects.
    q.push_back(16'hBEEF); q.push_back(16'h1234);
    d = new[1]; d[0] = 32'h04030201;
    if (q[0][7:0] !== 8'hEF) begin $display("FAIL q[0][7:0]=%h", q[0][7:0]); errors++; end
    if (q[1][15:12] !== 4'h1) begin $display("FAIL q[1][15:12]"); errors++; end
    if (q[0][11 -: 8] !== 8'hEE) begin $display("FAIL q -:"); errors++; end
    if (q[0][4 +: 8] !== 8'hEE) begin $display("FAIL q +:"); errors++; end
    if (q[0][3] !== 1'b1) begin $display("FAIL q bit"); errors++; end
    if (d[0][15:8] !== 8'h02) begin $display("FAIL d part"); errors++; end
    for (int i = 0; i < 4; i++)
      if (d[0][i*8 +: 8] !== (i+1)) begin $display("FAIL d +: i=%0d", i); errors++; end

    // (3) nested handle chain unpacked-array property element read.
    o.inr.arr[2] = 42;
    if (o.inr.arr[2] !== 42) begin $display("FAIL chain arr=%0d", o.inr.arr[2]); errors++; end
    o.inr.arr[0] = 7;
    if (o.inr.arr[0] + o.inr.arr[2] !== 49) begin $display("FAIL chain sum"); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule

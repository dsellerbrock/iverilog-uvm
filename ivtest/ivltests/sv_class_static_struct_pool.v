// Static array-of-struct class property: in-method member writes and
// external member reads (the original D3/D4 P0 shapes). History: an
// unqualified in-method write `pool[0].x = 3` ICE'd (net_assign
// assert); the external read `h.pool[0].x` was silently dropped, so
// comparisons folded to the wrong branch. Both were then made loud
// refusals, and the static-property array rework made them work; this
// test pins the working semantics. External member WRITES through the
// indexed property (h.pool[0].x = v) remain a loud sorry.
typedef struct { int x; int y; } pt_t;

module main;
  class holder;
    static pt_t pool[3];
    function void seed();
      pool[0].x = 3;
      pool[0].y = 7;
      pool[2].x = 30;
    endfunction
    static function void seed2();
      pool[1].x = 42;
    endfunction
  endclass

  holder h;
  int fails = 0;

  initial begin
    h = new;
    h.seed();
    holder::seed2();

    if (h.pool[0].x !== 3) begin fails++; $display("FAILED: p0x %0d", h.pool[0].x); end
    if (h.pool[0].y !== 7) begin fails++; $display("FAILED: p0y %0d", h.pool[0].y); end
    if (h.pool[1].x !== 42) begin fails++; $display("FAILED: p1x %0d", h.pool[1].x); end
    if (h.pool[2].x !== 30) begin fails++; $display("FAILED: p2x %0d", h.pool[2].x); end
    if (h.pool[1].y !== 0) begin fails++; $display("FAILED: p1y %0d", h.pool[1].y); end

    // comparison context (used to fold to the wrong branch)
    if (h.pool[0].x == 3) ; else begin fails++; $display("FAILED: compare branch"); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule

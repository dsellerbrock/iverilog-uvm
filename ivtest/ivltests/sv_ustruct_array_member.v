// Member access on an element of a STATIC (fixed-size) unpacked array of an
// UNPACKED struct. The array is stored as an array of objects whose elements
// are lazily default-constructed at run time, so `arr[i].field = x` on a
// never-whole-assigned element addresses a real object (previously the write
// was dropped and the case was diagnosed with a `sorry`). A member read of an
// unassigned element returns the struct default (0). (IEEE 1800-2017 7.2.1.)
module sv_ustruct_array_member;
  typedef struct { int x; int y; } p_t;
  p_t pa[3];
  int errors = 0;

  initial begin
    // Read before any write: default-constructed element reads as 0.
    if (pa[0].x != 0 || pa[2].y != 0) begin
      $display("FAIL default pa[0].x=%0d pa[2].y=%0d", pa[0].x, pa[2].y); errors++; end

    // Member writes to never-whole-assigned elements.
    pa[0].x = 1; pa[0].y = 2;
    pa[2].x = 5; pa[2].y = 6;
    // Leave pa[1] untouched (stays default 0).
    if (pa[0].x != 1 || pa[0].y != 2) begin
      $display("FAIL pa[0]=(%0d,%0d)", pa[0].x, pa[0].y); errors++; end
    if (pa[1].x != 0 || pa[1].y != 0) begin
      $display("FAIL pa[1]=(%0d,%0d) (expect 0,0)", pa[1].x, pa[1].y); errors++; end
    if (pa[2].x != 5 || pa[2].y != 6) begin
      $display("FAIL pa[2]=(%0d,%0d)", pa[2].x, pa[2].y); errors++; end

    // A member write after a whole-element assign also works.
    pa[1] = '{x:7, y:8};
    pa[1].x = 9;
    if (pa[1].x != 9 || pa[1].y != 8) begin
      $display("FAIL pa[1] after mix=(%0d,%0d)", pa[1].x, pa[1].y); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule

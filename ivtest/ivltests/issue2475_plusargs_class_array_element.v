// Issue #2475: $value$plusargs into an element of a class property's fixed
// unpacked array stores the value. IEEE 1800-2023 21.6: when the plusarg is
// found, "the resulting value is stored in the variable provided".
// The index may be any expression; a nested property chain works too, and
// a plusarg that is not found leaves the element unchanged.
module issue2475_plusargs_class_array_element;
  class inner_t; int v[3] = '{1, 2, 3}; endclass
  class c_t;
    int arr[2] = '{5, 6};
    logic [7:0] b[4];
    int md[2][3];
    inner_t in;
    int dq[];
    function new;
      in = new;
      foreach (b[i]) b[i] = 8'h10 + i;
      md[1][2] = 12;
      dq = '{4, 5, 6};
    endfunction
  endclass
  c_t c;
  int ok_a, ok_b, ok_n, ok_m, ok_miss, k = 1, failed = 0;
  initial begin
    c = new;
    ok_a = $value$plusargs("AE=%d", c.arr[1]);
    ok_b = $value$plusargs("BE=%h", c.b[k + 2]);
    ok_n = $value$plusargs("NE=%d", c.in.v[k]);
    ok_m = $value$plusargs("ME=%d", c.md[1][2]);
    ok_miss = $value$plusargs("MISSING=%d", c.arr[0]);
    if (ok_a != 1 || c.arr[1] != 77 || c.arr[0] != 5) begin
      $display("FAILED: arr = %0d %0d (ok=%0d)", c.arr[0], c.arr[1], ok_a); failed++;
    end
    if (ok_b != 1 || c.b[3] !== 8'hab || c.b[2] !== 8'h12) begin
      $display("FAILED: b = %h %h (ok=%0d)", c.b[2], c.b[3], ok_b); failed++;
    end
    if (ok_n != 1 || c.in.v[1] != 42 || c.in.v[0] != 1 || c.in.v[2] != 3) begin
      $display("FAILED: in.v = %0d %0d %0d (ok=%0d)", c.in.v[0], c.in.v[1], c.in.v[2], ok_n); failed++;
    end
    if (ok_m != 1 || c.md[1][2] != 70) begin
      $display("FAILED: md[1][2] = %0d (ok=%0d)", c.md[1][2], ok_m); failed++;
    end
    if (ok_miss != 0 || c.arr[0] != 5) begin
      $display("FAILED: a missing plusarg changed arr[0] = %0d", c.arr[0]); failed++;
    end
    // $cast takes the same writable element handle.
    if (!$cast(c.md[0][1], 8'd9) || c.md[0][1] != 9) begin
      $display("FAILED: $cast into md[0][1] gave %0d", c.md[0][1]); failed++;
    end
    // Reads of dynamic-array elements keep working.
    if (c.dq[1] != 5) begin $display("FAILED: dq[1] = %0d", c.dq[1]); failed++; end
    $display("arr=%0d %0d b=%h %h v=%0d %0d %0d md=%0d", c.arr[0], c.arr[1],
             c.b[2], c.b[3], c.in.v[0], c.in.v[1], c.in.v[2], c.md[1][2]);
    if (failed == 0) $display("PASSED");
  end
endmodule

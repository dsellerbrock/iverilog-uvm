// Regression: WRITE a part-select / bit-select of an element of an unpacked
// ARRAY class property, e.g. `bit[63:0] a[N]` assigned as `a[i][31:0] = x`,
// `a[i][j] = b` (runtime bit offset), or 2-D `a[i][j][63:32] = x`.
//
// Previously the l-value elaborated the trailing part-select as a second array
// dimension ("Got 2 indices, expecting 1"). After splitting the index into the
// array word + a packed-element part-select (set_word + set_part with a packed
// data type so the l-value's net_type() is the part, not the enclosing object),
// the store is generated as a read-modify-write via the %store/prop/v/i/bits
// opcode (array index + bit offset, both possibly runtime, in registers).
//
// This is the OpenTitan scoreboard write pattern (timer_val[i][31:0],
// intr_status_exp[i][j], compare_val[i][j][31:0]).
module top;
  class c;
    bit [63:0] arr[4];
    bit [31:0] st[2];
    bit [63:0] cv[2][3];
    function void set_word(int i, bit [63:0] v); arr[i] = v; endfunction
  endclass

  initial begin
    c o = new();
    int e = 0;
    o = new();

    // const part-select writes on a 1-D array element
    o.arr[2][31:0]  = 32'hDEAD5678;
    o.arr[2][63:32] = 32'hBEEF1234;
    if (o.arr[2] != 64'hBEEF1234DEAD5678) begin
      $display("FAIL arr2=%h", o.arr[2]); e++;
    end

    // runtime bit-offset write: st[1][5] = 1  (j is a runtime value)
    for (int j = 0; j < 8; j++)
      if (j == 5) o.st[1][j] = 1'b1;
    if (o.st[1] != 32'h20)        begin $display("FAIL st1=%h", o.st[1]); e++; end
    if (o.st[1][5] !== 1'b1)      begin $display("FAIL st1b5"); e++; end
    if (o.st[1][4] !== 1'b0)      begin $display("FAIL st1b4"); e++; end

    // 2-D array element, const part write
    o.cv[0][2][63:32] = 32'hCAFEF00D;
    o.cv[0][2][31:0]  = 32'h00C0FFEE;
    if (o.cv[0][2] != 64'hCAFEF00D00C0FFEE) begin
      $display("FAIL cv=%h", o.cv[0][2]); e++;
    end

    if (e == 0) $display("PASS");
    else $display("FAILED with %0d errors", e);
  end
endmodule

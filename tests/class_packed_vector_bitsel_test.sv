// Bit-select (read AND write) of a PACKED-VECTOR class property.
//
// `bit [1:0] p` is a single 2-bit value; p[0]/p[1] are BIT-selects.  iverilog
// stored such a property as property_bit(wid=2,array_size=1) and routed p[i]
// to the ELEMENT-indexed %prop/v/i opcode -> p[0] returned the whole value,
// p[1] was out of range -> X, and p[i]=v writes were silently dropped.
// Fixed by detecting a packed-vector property (ivl_type_element==null) and
// emitting %prop/v + %part bit-select (read) / %store/prop/v/i/bits RMW
// (write) instead.  This is the OpenTitan aon_timer_scoreboard
// intr_status_exp[WKUP]/[WDOG] miscompile.
//
// Control: a genuine unpacked array property must KEEP element indexing.
module top;
  class C;
    bit [1:0]  p;        // packed vector  -> bit-select
    bit [3:0]  q;        // wider packed vector
    int        arr[3];   // unpacked array -> element index (must still work)
  endclass

  initial begin
    C c = new();
    bit ok = 1'b1;

    // ---- read bit-selects ----
    c.p = 2'b10;
    if (c.p[0] !== 1'b0) begin ok = 0; $display("FAIL p[0]=%b exp 0", c.p[0]); end
    if (c.p[1] !== 1'b1) begin ok = 0; $display("FAIL p[1]=%b exp 1", c.p[1]); end

    c.q = 4'b1010;
    if (c.q[0] !== 1'b0 || c.q[1] !== 1'b1 ||
        c.q[2] !== 1'b0 || c.q[3] !== 1'b1) begin
      ok = 0; $display("FAIL q bitsel q=%b", c.q);
    end

    // ---- write bit-selects (read-modify-write of the packed value) ----
    c.p = '0;
    c.p[1] = 1'b1;
    if (c.p !== 2'b10) begin ok = 0; $display("FAIL write p[1]=1 -> p=%b exp 10", c.p); end
    c.p[0] = 1'b1;
    if (c.p !== 2'b11) begin ok = 0; $display("FAIL write p[0]=1 -> p=%b exp 11", c.p); end

    // ---- runtime index ----
    for (int i = 0; i < 4; i++) begin
      c.q = '0;
      c.q[i] = 1'b1;
      if (c.q[i] !== 1'b1) begin ok = 0; $display("FAIL runtime q[%0d]", i); end
    end

    // ---- control: unpacked array element index must be unaffected ----
    c.arr[0] = 11; c.arr[1] = 22; c.arr[2] = 33;
    if (c.arr[0] != 11 || c.arr[1] != 22 || c.arr[2] != 33) begin
      ok = 0; $display("FAIL unpacked array element index regressed");
    end

    if (ok) $display("PACKED_VECTOR_BITSEL_PASS");
    else    $display("PACKED_VECTOR_BITSEL_FAIL");
    $finish;
  end
endmodule

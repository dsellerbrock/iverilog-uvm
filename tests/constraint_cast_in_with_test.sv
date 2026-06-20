// Regression: a width-cast on the RHS of an inline `randomize() with {}`
// equality constraint must be honored (IEEE 1800-2017 §18.4 / §6.24.1).
//
// iverilog's constraint-to-Z3-IR lowering (pexpr_to_constraint_ir) had no
// handler for cast nodes (PECastSize / PECastType / PECastSign).  A cast
// therefore fell through to `return ""`, which made the enclosing `==`
// relation collapse (the PEBinary handler returns "" if either operand is
// empty) and the WHOLE constraint was silently dropped — leaving the rand
// field free (random value).
//
// This is the OpenTitan reg-adapter case (tl_reg_adapter::fill_bus_wr):
//     bus_req.randomize() with {
//       bus_req.a_addr == AddrWidth'(rw.addr);   // 64-bit rw.addr -> 32-bit
//       bus_req.a_data == DataWidth'(rw.data);
//     }
// Without the fix every CSR write went to a RANDOM address, so no DUT
// register was ever configured.
//
// The fix lowers a cast by recursing into its base (a non-rand base becomes a
// runtime value slot, elaborated at 32-bit width — which applies the cast's
// 64->32 truncation for free).

module top;

  typedef struct packed { logic [31:0] addr; logic [31:0] data; } op_t;

  class item;
    rand bit [31:0] a_addr;
    rand bit [31:0] a_data;
  endclass

  initial begin
    item     it;
    op_t     rw;
    bit [63:0] wide;          // 64-bit state var (like uvm_reg_addr_t)
    int errors = 0;

    it = new();
    rw.addr = 32'h0000_0010;  // CTRL offset, as in OT
    rw.data = 32'h5397_0007;
    wide    = 64'hDEAD_0000_0000_0010;  // low 32 bits = 0x10 after cast

    for (int i = 0; i < 20; i++) begin
      // size-cast of a packed-struct member (the OT pattern)
      if (!it.randomize() with { a_addr == 32'(rw.addr); a_data == 32'(rw.data); }) begin
        $display("FAIL: randomize (struct-member cast) returned 0"); errors++;
      end else if (it.a_addr !== 32'h10 || it.a_data !== 32'h5397_0007) begin
        $display("FAIL: cast-constraint dropped: a_addr=0x%08h a_data=0x%08h", it.a_addr, it.a_data);
        errors++;
      end

      // 64->32 truncating cast of a wide state var
      if (!it.randomize() with { a_addr == 32'(wide); }) begin
        $display("FAIL: randomize (64->32 cast) returned 0"); errors++;
      end else if (it.a_addr !== 32'h10) begin
        $display("FAIL: 64->32 cast not truncated: a_addr=0x%08h (expected 0x10)", it.a_addr);
        errors++;
      end
    end

    if (errors == 0) $display("PASS");
    else $display("constraint_cast_in_with_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule

// Regression: property assignment through an INDEXED aggregate element.
//
// Root cause (docs/conformance/m7_stress_findings_2026-07-18.md, Finding 6):
// `container[idx].prop = val` mis-compiled two ways, which silently dropped
// the uvm_reg register-address cache (`m_regs_info[rg].addr = addrs` inside
// Xinit_address_mapX, so uvm_reg::get_address returned 0):
//
//   (a) ASSOC array keyed by a class handle: draw_lval_expr coerced the class
//       key to an integer and loaded the element with %load/dar/obj (a darray
//       word index built from the key's null-test flag) instead of %aa/load
//       with the real key — the property store hit a garbage object.
//   (b) whole-DARRAY-typed property store through an indexed base: the base
//       (container) index was mistaken for a property element index, so the
//       store became %prop/obj (load) + %set/dar (set one element) instead of
//       %store/prop/obj (replace the whole property) — a silent no-op.
//
// Both are fixed in tgt-vvp/stmt_assign.c. The register model reads the cache
// back through a local handle (info = m_regs_info[rg]; info.addr ...), so the
// checks below mirror that write-through-indexed / read-through-local pattern.
//
// Prints "PASS" only if every check holds.
`timescale 1ns/1ns

class keyc; endclass
class info_t;
  int unsigned    n;
  bit [63:0]      addr[];
endclass

module m7_indexed_property_store_test;
  int errors = 0;

  // assoc array keyed by a class handle (the m_regs_info shape)
  info_t by_key [keyc];
  // dynamic array of class handles
  info_t da [];
  bit [63:0] payload [];

  initial begin
    keyc  k     = new;
    info_t peek;

    by_key[k] = new;
    da        = new[1];
    da[0]     = new;
    payload   = new[2];
    payload[0] = 64'h0000_0100;
    payload[1] = 64'h0000_0104;

    // (a) scalar property through an assoc[classkey] base, read back directly.
    by_key[k].n = 42;
    if (by_key[k].n !== 42) begin
      errors++; $display("FAIL (a-scalar): by_key[k].n=%0d exp 42", by_key[k].n);
    end

    // (a) darray property through an assoc[classkey] base, read back directly.
    by_key[k].addr = payload;
    if (by_key[k].addr.size() != 2
        || by_key[k].addr[0] !== 64'h100 || by_key[k].addr[1] !== 64'h104) begin
      errors++; $display("FAIL (a-darray): assoc-base darray property store");
    end

    // (b) darray property through a darray[idx] base — the exact register
    //     cache write. Verify through a local handle, as uvm_reg does.
    da[0].addr = payload;
    peek = da[0];
    if (peek.addr.size() != 2
        || peek.addr[0] !== 64'h100 || peek.addr[1] !== 64'h104) begin
      errors++; $display("FAIL (b): darray-base darray property store (read via local)");
    end

    // (c) scalar property through a darray[idx] base (baseline, always worked).
    da[0].n = 7;
    if (da[0].n !== 7) begin
      errors++; $display("FAIL (c): darray-base scalar property store");
    end

    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d sub-check(s) failed", errors);
  end
endmodule

// Regression for the ref-dyn-array copy-out miscompile
// (docs/conformance/m7_stress_findings_2026-07-18.md, finding 2):
// a function call passing a dynamic array by ref lost the write-back
// when another argument expression contained a method call. The
// nested %alloc/%callf/%free between the outer call's %alloc and its
// argument stores made of_FREE hand the read context to the staged
// (not-yet-called) outer frame; do_join's wt!=rd staging test then
// saw equal contexts, skipped the callee-frame pop-push, and the
// post-call copy-back stored through the callee frame instead of the
// caller frame. Fixed by only running the of_FREE read handoff when
// the post-removal read head is dead.
//
// This is the reduced shape of uvm_reg_map::do_bus_access's
// get_physical_addresses_to_map call, which made the whole UVM RAL
// front-door a silent no-op.

typedef bit [63:0] addr_t;

class info_t;
  addr_t offset;
endclass

class regc;
  function int unsigned get_n_bytes();
    return 4;
  endfunction
endclass

class mapper;
  info_t m_regs_info [regc];

  function int gpa(addr_t base, addr_t off, int unsigned n,
                   ref addr_t addr[], input mapper parent,
                   ref int unsigned skip);
    addr = new[1];
    addr[0] = base + n;
    return 0;
  endfunction

  function int check(regc r);
    addr_t adr[];
    int unsigned byte_offset;
    int bad = 0;

    // method call in an earlier argument (the failing shape)
    void'(gpa(64'h4, 0, r.get_n_bytes(), adr, null, byte_offset));
    if (adr.size() != 1 || adr[0] !== 64'h8) bad += 1;
    adr.delete();

    // assoc-array member access in an earlier argument
    void'(gpa(m_regs_info[r].offset, 0, 4, adr, null, byte_offset));
    if (adr.size() != 1 || adr[0] !== 64'hc) bad += 1;
    adr.delete();

    // both at once
    void'(gpa(m_regs_info[r].offset, 0, r.get_n_bytes(), adr, null, byte_offset));
    if (adr.size() != 1 || adr[0] !== 64'hc) bad += 1;
    adr.delete();

    // plain constant arguments (was always fine)
    void'(gpa(64'h1, 0, 2, adr, null, byte_offset));
    if (adr.size() != 1 || adr[0] !== 64'h3) bad += 1;

    return bad;
  endfunction
endclass

module m7_ref_arg_copyout_test;
  initial begin
    mapper m;
    regc r;
    info_t inf;
    int bad;
    m = new;
    r = new;
    inf = new;
    inf.offset = 8;
    m.m_regs_info[r] = inf;
    bad = m.check(r);
    if (bad == 0)
      $display("PASS: ref dyn-array copy-out survives complex sibling arguments");
    else
      $display("FAIL: %0d of 4 ref copy-out shapes lost the write-back", bad);
    $finish(0);
  end
endmodule

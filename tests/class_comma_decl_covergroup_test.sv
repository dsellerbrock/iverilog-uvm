// Regression: comma-separated class property declarations (`int a, b;`) shared
// ONE data_type_t* across multiple owning unique_ptr<data_type_t> in
// class_type_t::prop_info_t. At class teardown each prop_info_t deleted the
// SAME shared type node (often the static netvector_t::atom2s32 singleton),
// a double-free that crashed in class_type_t::~class_type_t. A 2+ coverpoint
// covergroup (whose synthesized __bin_/__xbin_ properties are emitted this way)
// reliably triggered it (OpenTitan pattgen/sysrst_ctrl env coverage).
// Fix: prop_info_t::type is now non-owning (front-end type nodes live for the
// whole compile; leaking at exit is harmless and avoids the double-free).
module top;
  class c;
    int a, b;               // comma-decl, shares one data_type_t*
    bit [7:0] x, y, z;      // 3-way comma-decl
    covergroup cg;
      cp_a: coverpoint a;   // 2+ coverpoints synthesize multiple shared-type props
      cp_b: coverpoint b;
    endgroup
    function new(); cg = new(); endfunction
    function int sentinel(); a = 1; b = 2; x = 8'h11; return a + b; endfunction
  endclass
  initial begin
    c o = new();
    if (o.sentinel() == 3) $display("PASS");
    else $display("FAIL");
  end
endmodule

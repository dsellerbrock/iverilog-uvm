// Regression: assigning a whole dynamic array to a PROPERTY of a class object
// stored in an associative-array element must persist.
//
// OpenTitan #10 root cause: uvm_reg_map::Xinit_address_mapX does
//   m_regs_info[rg].addr = addrs;   // m_regs_info keyed by uvm_reg
// The store was silently DROPPED -> map_info.addr empty ->
// uvm_reg::get_address()==0 for every register -> csr_addrs all 0 ->
// scoreboard mispredicted d_error (unmapped) on valid CSR accesses.
//
// Root cause: prop_lval_index_expr_ (tgt-vvp/stmt_assign.c) fell back to the
// NESTED lval's index when the property had no own index. For aa[key].darray
// the nest index is the associative-array KEY (already consumed to load the
// receiver); reusing it as a darray element index turned the whole-array store
// into a bogus element set. Scalar property writes were unaffected.
//
// Persistence is verified through the SHARED object handle (the same object is
// also held in a plain variable), since the store goes through that handle.
//
// KNOWN SEPARATE LIMITATION (not covered here): a whole-darray store to a
// property of a STATIC unpacked-array element (static_arr[i].darray = whole)
// hits a distinct, pre-existing gap in the whole-array property-store codegen
// for static-array-element receivers. It is not on the OpenTitan path
// (m_regs_info is associative) and is left for a follow-up.

class info;
  int addr[];
  int offset;
endclass

class rk; int id; endclass   // object key, like uvm_reg

module top;
  initial begin
    info aa_i[int];
    info aa_o[rk];
    info v = new(), vo = new();
    rk   k = new();
    int  src[];
    int  errors = 0;

    src = new[3]; src[0]=10; src[1]=11; src[2]=12;

    // (A) int-keyed assoc element: whole-darray property store
    aa_i[5] = v;
    aa_i[5].addr = src;
    if (v.addr.size()!=3 || v.addr[2]!==12) begin $display("FAIL A: size=%0d", v.addr.size()); errors++; end

    // (B) object-keyed assoc element (the OT m_regs_info pattern)
    aa_o[k] = vo;
    aa_o[k].addr = src;
    if (vo.addr.size()!=3) begin $display("FAIL B: size=%0d", vo.addr.size()); errors++; end

    // (D) scalar property write via assoc element (must still work)
    aa_i[5].offset = 42;
    if (v.offset!==42) begin $display("FAIL D: scalar write"); errors++; end

    if (errors==0) $display("PASS");
    else $display("assoc_elem_darray_property_write_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule

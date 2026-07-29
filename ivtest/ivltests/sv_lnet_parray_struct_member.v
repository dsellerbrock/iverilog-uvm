// A continuous assignment to an element of a packed ARRAY OF STRUCTS that is
// itself a struct member -- `assign hw2reg.key[3].d = ...' -- used to abort
// the compiler outright:
//
//   ivl: elab_net.cc:695: NetNet* PEIdent::elaborate_lnet_common_(...):
//        Assertion `use_path.empty()' failed.
//
// The member walk stepped into `key', found its type was a packed array
// rather than a struct, and asserted that nothing followed -- but `.d' did.
// The procedural lvalue path already handled this shape; only the
// continuous-assignment path aborted.
//
// This is the register-file interface shape every OpenTitan comportable IP
// generates (`hw2reg.key[i].d', with `key' declared `key_mreg_t [31:0]').
//
// The test checks the OFFSETS are right, not merely that it compiles: each
// element gets a distinct value and every field is read back.

module sv_lnet_parray_struct_member;

  typedef struct packed {
    logic [7:0] d;
    logic       de;
  } fld_t;

  typedef struct packed {
    fld_t [3:0] key;
    logic [7:0] tail;
  } hw2reg_t;

  hw2reg_t hw2reg;

  // Continuous assignment into each array element's members. This is the
  // construct that used to crash.
  for (genvar i = 0; i < 4; i++) begin : gen_key
    assign hw2reg.key[i].d  = 8'h10 + i;
    assign hw2reg.key[i].de = i[0];
  end

  assign hw2reg.tail = 8'hA5;

  int errors = 0;

  // Readback uses CONSTANT indices on purpose: a variable index into a
  // packed array member is a separate, still-open gap, and this test is
  // about the continuous-assignment crash.
  task automatic chk(input int idx, input [7:0] got_d, input got_de);
    if (got_d !== (8'h10 + idx)) begin
      $display("FAILED -- hw2reg.key[%0d].d = %h, want %h", idx, got_d, 8'h10 + idx);
      errors++;
    end
    if (got_de !== idx[0]) begin
      $display("FAILED -- hw2reg.key[%0d].de = %b, want %b", idx, got_de, idx[0]);
      errors++;
    end
  endtask

  initial begin
    #1;
    chk(0, hw2reg.key[0].d, hw2reg.key[0].de);
    chk(1, hw2reg.key[1].d, hw2reg.key[1].de);
    chk(2, hw2reg.key[2].d, hw2reg.key[2].de);
    chk(3, hw2reg.key[3].d, hw2reg.key[3].de);

    // A member after the array must not have been clobbered by a
    // mis-scaled element offset.
    if (hw2reg.tail !== 8'hA5) begin
      $display("FAILED -- hw2reg.tail = %h, want a5 (element offset overran)",
               hw2reg.tail);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule

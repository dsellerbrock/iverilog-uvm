// Regression: a continuous-assignment LHS that indexes a packed-array-of-struct
// member and then descends into a field, e.g. `reg2hw.data[i].q`, aborted in
// PEIdent::elaborate_lnet_common_ (elab_net.cc) with
//   Assertion `use_path.empty()' failed
// because the member-path walker only descended through plain netstruct_t
// members; a member whose type is a netparray_t (packed array) of struct left
// path components (".q") unconsumed. This pattern is pervasive in every
// OpenTitan *_reg_top.sv (`reg2hw.<field>[i].q` output connections), so the
// abort blocked every block's cover_reg_top build. The walker now applies the
// element index to advance the bit offset and descends into the element struct.
module top;
  typedef struct packed { logic [7:0] q; } mreg_t;
  typedef struct packed { mreg_t [1:0] data; logic [3:0] other; } reg2hw_t;
  reg2hw_t reg2hw;
  logic [7:0] src0, src1;
  // Element 0 occupies the low byte of `data`, element 1 the high byte.
  assign reg2hw.data[0].q = src0;
  assign reg2hw.data[1].q = src1;
  initial begin
    src0 = 8'hAA; src1 = 8'h55; #1;
    if (reg2hw.data[0].q == 8'hAA && reg2hw.data[1].q == 8'h55)
      $display("PASS");
    else
      $display("FAIL got %h %h", reg2hw.data[0].q, reg2hw.data[1].q);
  end
endmodule

package tl_const_pkg;
  parameter int MaskWidth = 4;
  parameter int SizeWidth = 2;

  typedef enum bit [2:0] {
    PutFullData    = 3'd0,
    PutPartialData = 3'd1,
    Get            = 3'd4
  } tl_a_op_e;
  typedef enum bit [2:0] {
    AccessAck     = 3'd0,
    AccessAckData = 3'd1
  } tl_d_op_e;
endpackage

package constraint_imported_constants_pkg;
  import tl_const_pkg::*;

  class tl_item;
    rand bit [31:0] a_addr;
    rand bit [MaskWidth-1:0] a_mask;
    rand bit [SizeWidth-1:0] a_size;
    rand bit [2:0] a_opcode;
    rand bit [2:0] d_opcode;

    constraint a_opcode_c {
      a_opcode inside {Get, PutFullData, PutPartialData};
    }
    constraint d_opcode_c {
      d_opcode inside {AccessAckData, AccessAck};
    }
    constraint mask_contiguous_c {
      $countones(a_mask ^ {a_mask[MaskWidth-2:0], 1'b0}) <= 2;
    }
    constraint mask_w_full_c {
      a_opcode == PutFullData ->
        $countones(a_mask) == (1 << a_size);
    }
    constraint mask_in_active_lanes_c {
      (a_mask & ~(((1 << (1 << a_size)) - 1)
                  << a_addr[SizeWidth-1:0])) == 0;
    }
    constraint addr_size_align_c {
      (a_addr & ((1 << a_size) - 1)) == 0;
    }
    constraint max_size_c { a_size <= 2; }
  endclass
endpackage

module constraint_imported_constants_test;
  import tl_const_pkg::*;
  import constraint_imported_constants_pkg::*;

  initial begin
    tl_item item;
    item = new;
    repeat (20) begin
      assert (item.randomize());
      assert (item.a_opcode inside {Get, PutFullData, PutPartialData});
      assert (item.d_opcode inside {AccessAckData, AccessAck});
      assert ($countones(item.a_mask ^ {item.a_mask[MaskWidth-2:0], 1'b0}) <= 2);
      if (item.a_opcode == PutFullData)
        assert ($countones(item.a_mask) == (1 << item.a_size));
      assert ((item.a_mask & ~(((1 << (1 << item.a_size)) - 1)
                              << item.a_addr[SizeWidth-1:0])) == 0);
      assert ((item.a_addr & ((1 << item.a_size) - 1)) == 0);
      assert (item.a_size <= 2);
    end
    $display("PASS constraint imported constants");
  end
endmodule

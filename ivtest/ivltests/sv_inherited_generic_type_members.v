package mvc_types_pkg;
  class mvc_sequence_item_base;
  endclass

  class ahb_master_burst_transfer extends mvc_sequence_item_base;
    bit RnW;
    bit [31:0] address;
    bit [2:0] size;
    bit [63:0] data[$];
    bit [1:0] resp[$];
  endclass
endpackage

package qvip_compat_pkg;
  import mvc_types_pkg::*;

  class ahb_reg_predictor #(type T = ahb_master_burst_transfer);
    virtual function void write(mvc_sequence_item_base tr);
      T transfer;
      T beat;
      if (!$cast(transfer, tr)) return;
      beat = new();
      beat.RnW = transfer.RnW;
      beat.size = transfer.size;
      for (int unsigned i = 0; i < transfer.data.size(); i++) begin
        beat.address = transfer.address + (i * (1 << transfer.size));
        beat.data.delete();
        beat.data.push_back(transfer.data[i]);
        beat.resp.delete();
        beat.resp.push_back(transfer.resp[i]);
      end
      if (beat.RnW !== transfer.RnW || beat.size !== transfer.size ||
          beat.address !== transfer.address || beat.data.size() != 1 ||
          beat.data[0] !== transfer.data[0] || beat.resp.size() != 1 ||
          beat.resp[0] !== transfer.resp[0])
        $fatal(1, "inherited generic base member access failed");
    endfunction
  endclass

  class pv_ahb_reg_predictor #(type T = int)
    extends ahb_reg_predictor #(.T(T));
    virtual function void write(mvc_sequence_item_base tr);
      T ahb_txn;
      if (!$cast(ahb_txn, tr))
        $fatal(1, "derived generic cast failed");
      if (ahb_txn.RnW !== 1'b1 || ahb_txn.address !== 32'h1000 ||
          ahb_txn.data.size() != 1 || ahb_txn.data[0] !== 64'h1234)
        $fatal(1, "derived generic member access failed");
      super.write(tr);
    endfunction
  endclass
endpackage

module sv_inherited_generic_type_members;
  import mvc_types_pkg::*;
  import qvip_compat_pkg::*;

  ahb_master_burst_transfer transfer;
  pv_ahb_reg_predictor #(ahb_master_burst_transfer) predictor;

  initial begin
    transfer = new();
    predictor = new();
    transfer.RnW = 1;
    transfer.address = 32'h1000;
    transfer.data.push_back(64'h1234);
    transfer.resp.push_back(2'b00);
    predictor.write(transfer);
    $display("PASSED");
  end
endmodule

interface flash_packed_missing_if;
  typedef struct packed {
    logic [7:0] addr;
  } entry_t;
  entry_t [1:0][1:0] rd_buf;
endinterface

class flash_packed_missing_cfg;
  virtual flash_packed_missing_if vif;
endclass

module top;
  flash_packed_missing_if fi();
  flash_packed_missing_cfg cfg;
  logic [7:0] result;
  initial begin
    cfg = new;
    cfg.vif = fi;
    result = cfg.vif.rd_buf[1][0].missing;
  end
endmodule

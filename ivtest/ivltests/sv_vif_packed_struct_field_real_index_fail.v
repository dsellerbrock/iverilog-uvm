interface flash_packed_real_index_if;
  typedef struct packed {
    logic [7:0] addr;
  } entry_t;
  entry_t [1:0][1:0] rd_buf;
endinterface

class flash_packed_real_index_cfg;
  virtual flash_packed_real_index_if vif;
endclass

module top;
  flash_packed_real_index_if fi();
  flash_packed_real_index_cfg cfg;
  logic [7:0] result;
  real bad;
  initial begin
    cfg = new;
    cfg.vif = fi;
    bad = 0.0;
    result = cfg.vif.rd_buf[0][bad].addr;
  end
endmodule

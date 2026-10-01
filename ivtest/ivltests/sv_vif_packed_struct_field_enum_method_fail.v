interface flash_packed_enum_method_if;
  typedef enum logic [1:0] { IDLE = 0, RUN = 1 } state_e;
  typedef struct packed {
    state_e state;
    logic flag;
  } entry_t;
  entry_t [1:0][1:0] rd_buf;
endinterface

class flash_packed_enum_method_cfg;
  virtual flash_packed_enum_method_if vif;
endclass

module top;
  flash_packed_enum_method_if fi();
  flash_packed_enum_method_cfg cfg;
  string name;
  initial begin
    cfg = new;
    cfg.vif = fi;
    name = cfg.vif.rd_buf[1][0].state.name();
  end
endmodule

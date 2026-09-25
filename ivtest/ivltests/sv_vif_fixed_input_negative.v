`include "ivltests/sv_vif_fixed_input_common.vh"

module sv_vif_fixed_input_bad_size;
  vif_fixed_input_if concrete();
  virtual vif_fixed_input_if vif;
  vif_lock_t actual[0:1];
  initial begin vif = concrete; vif.consume(actual); end
endmodule

module sv_vif_fixed_input_bad_type;
  vif_fixed_input_if concrete();
  virtual vif_fixed_input_if vif;
  int actual[0:2];
  initial begin vif = concrete; vif.consume(actual); end
endmodule

module sv_vif_fixed_input_bad_scalar;
  vif_fixed_input_if concrete();
  virtual vif_fixed_input_if vif;
  vif_lock_t actual;
  initial begin vif = concrete; vif.consume(actual); end
endmodule

module sv_vif_fixed_input_unsupported_directions;
  vif_fixed_input_if concrete();
  virtual vif_fixed_input_if vif;
  vif_lock_t actual[0:2];
  initial begin
    vif = concrete;
    vif.take_out(actual);
    vif.take_inout(actual);
    vif.take_ref(actual);
  end
endmodule

interface vif_fixed_default_if;
  task automatic take(input int values[0:1] = '{3, 4});
  endtask
endinterface

module sv_vif_fixed_input_unsupported_default;
  vif_fixed_default_if concrete();
  virtual vif_fixed_default_if vif;
  initial begin vif = concrete; vif.take(); end
endmodule

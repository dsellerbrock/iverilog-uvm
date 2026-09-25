interface nested_value_modport_leaf_if;
endinterface

interface nested_value_modport_outer_if;
  logic visible;
  nested_value_modport_leaf_if child();
  modport restricted(input visible);
endinterface

class nested_value_modport_cfg;
  virtual nested_value_modport_outer_if.restricted vif;
endclass

class nested_value_modport_sink;
  function void put(virtual nested_value_modport_leaf_if value);
  endfunction
endclass

module sv_vif_class_nested_value_wrong_modport_fail;
  nested_value_modport_outer_if outer();
  nested_value_modport_cfg cfg;
  nested_value_modport_sink sink;

  initial begin
    cfg = new;
    sink = new;
    cfg.vif = outer.restricted;
    sink.put(cfg.vif.child);
  end
endmodule

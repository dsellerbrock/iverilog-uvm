interface nested_value_missing_leaf_if;
endinterface

interface nested_value_missing_outer_if;
  nested_value_missing_leaf_if present();
endinterface

class nested_value_missing_cfg;
  virtual nested_value_missing_outer_if vif;
endclass

class nested_value_missing_sink;
  function void put(virtual nested_value_missing_leaf_if value);
  endfunction
endclass

module sv_vif_class_nested_value_missing_fail;
  nested_value_missing_outer_if outer();
  nested_value_missing_cfg cfg;
  nested_value_missing_sink sink;

  initial begin
    cfg = new;
    sink = new;
    cfg.vif = outer;
    sink.put(cfg.vif.absent);
  end
endmodule

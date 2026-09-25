interface nested_value_expected_if;
endinterface

interface nested_value_other_if;
endinterface

interface nested_value_wrong_type_outer_if;
  nested_value_other_if child();
endinterface

class nested_value_wrong_type_cfg;
  virtual nested_value_wrong_type_outer_if vif;
endclass

class nested_value_wrong_type_sink;
  function void put(virtual nested_value_expected_if value);
  endfunction
endclass

module sv_vif_class_nested_value_wrong_type_fail;
  nested_value_wrong_type_outer_if outer();
  nested_value_expected_if expected();
  nested_value_wrong_type_cfg cfg;
  nested_value_wrong_type_sink sink;

  initial begin
    cfg = new;
    sink = new;
    cfg.vif = outer;
    sink.put(cfg.vif.child);
  end
endmodule

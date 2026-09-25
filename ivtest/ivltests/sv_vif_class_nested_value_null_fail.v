interface nested_value_null_leaf_if;
endinterface

interface nested_value_null_outer_if;
  nested_value_null_leaf_if child();
endinterface

class nested_value_null_cfg;
  virtual nested_value_null_outer_if vif;
endclass

class nested_value_null_sink;
  function void put(virtual nested_value_null_leaf_if value);
  endfunction
endclass

module sv_vif_class_nested_value_null_fail;
  nested_value_null_outer_if exemplar();
  nested_value_null_cfg cfg;
  nested_value_null_sink sink;

  initial begin
    cfg = new;
    sink = new;
    sink.put(cfg.vif.child);
    $display("UNREACHABLE null nested child accepted");
  end
endmodule

// Fixed unpacked-array inputs require aggregate marshalling into the selected
// interface method activation. Until that copy path exists, reject the call
// rather than lowering the array expression as a scalar or binding one
// arbitrary interface instance.

interface vif_input_array_if;
  task automatic consume(input int values[2]);
  endtask
endinterface

module sv_vif_input_array_method_fail;
  vif_input_array_if only_instance();
  virtual vif_input_array_if vif;
  int values[2];

  initial begin
    vif = only_instance;
    vif.consume(values);
  end
endmodule

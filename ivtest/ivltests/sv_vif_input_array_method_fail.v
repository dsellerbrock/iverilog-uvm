// Multi-dimensional fixed unpacked-array task inputs still need a selected
// interface method marshaller; keep the unsupported boundary loud.

interface vif_input_array_if;
  task automatic consume(input int values[2][2]);
  endtask
endinterface

module sv_vif_input_array_method_fail;
  vif_input_array_if only_instance();
  virtual vif_input_array_if vif;
  int values[2][2];

  initial begin
    vif = only_instance;
    vif.consume(values);
  end
endmodule

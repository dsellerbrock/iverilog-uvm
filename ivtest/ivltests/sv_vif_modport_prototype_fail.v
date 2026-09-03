// IEEE 1800-2017/2023 25.7 negative controls for full modport
// task/function prototypes. Each call below has one independent error.

interface proto_bad_return_if;
  function int calculate(input int value);
    return value;
  endfunction
  modport selected(
      import function logic calculate(input int value));
endinterface

interface proto_bad_name_if;
  function int calculate(input int implementation_value = 3);
    return implementation_value;
  endfunction
  modport selected(
      import function int calculate(input int prototype_value = 3));
endinterface

interface proto_missing_named_if;
  function int calculate(input int value);
    return value;
  endfunction
  modport selected(import calculate);
endinterface

interface proto_missing_default_if;
  function int calculate(input int value = 9);
    return value;
  endfunction
  modport selected(import calculate);
endinterface

module sv_vif_modport_prototype_fail;
  proto_bad_return_if bad_return_inst();
  proto_bad_name_if bad_name_inst();
  proto_missing_named_if missing_named_inst();
  proto_missing_default_if missing_default_inst();

  virtual proto_bad_return_if.selected bad_return_vif;
  virtual proto_bad_name_if.selected bad_name_vif;
  virtual proto_missing_named_if.selected missing_named_vif;
  virtual proto_missing_default_if.selected missing_default_vif;
  int sink;

  initial begin
    bad_return_vif = bad_return_inst;
    bad_name_vif = bad_name_inst;
    missing_named_vif = missing_named_inst;
    missing_default_vif = missing_default_inst;

    sink = bad_return_vif.calculate(.value(1));
    sink = bad_name_vif.calculate(.prototype_value(2));
    sink = missing_named_vif.calculate(.value(3));
    sink = missing_default_vif.calculate();
  end
endmodule

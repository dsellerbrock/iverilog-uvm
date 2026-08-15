class vif_default_missing_use #(
  type IFType = virtual vif_default_missing_if
);
  IFType value;
endclass

module sv_typeparam_virtual_interface_default_use_fail;
  vif_default_missing_use object;
endmodule

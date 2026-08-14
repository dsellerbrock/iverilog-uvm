class vif_default_known_noninterface_type;
endclass

class vif_default_known_noninterface_holder #(
  type IFType = virtual interface vif_default_known_noninterface_type
);
  IFType value;
endclass

module sv_typeparam_virtual_interface_known_noninterface_fail;
  vif_default_known_noninterface_holder object;
endmodule

// The forward IDENTIFIER spelling is legal to parse, but ordinary class
// properties must resolve to a real interface declaration during elaboration.
class vif_explicit_interface_missing_holder;
  virtual interface vif_explicit_interface_missing_if vif;
endclass

module virtual_interface_explicit_class_missing_definition;
  vif_explicit_interface_missing_holder object;

  initial object = new();
endmodule

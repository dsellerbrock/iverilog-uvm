interface vif_default_known_if;
  logic signal;
endinterface

class vif_default_known_short #(
  type IFType = virtual vif_default_known_if
);
endclass

class vif_default_known_explicit #(
  type IFType = virtual interface vif_default_known_if
);
endclass

class vif_default_forward_short #(
  type IFType = virtual vif_default_late_short_if
);
endclass

class vif_default_forward_explicit #(
  type IFType = virtual interface vif_default_late_explicit_if
);
endclass

class vif_default_unused_short #(
  type IFType = virtual vif_default_never_short_if
);
endclass

class vif_default_unused_explicit #(
  parameter type IFType = virtual interface vif_default_never_explicit_if
);
endclass

class vif_default_unused_list #(
  type First = virtual vif_default_never_first_if,
       Second = virtual interface vif_default_never_second_if
);
endclass

class vif_default_unused_alias #(
  type IFType = virtual vif_default_never_alias_if,
       AliasType = IFType
);
endclass

interface vif_default_late_short_if;
  logic signal;
endinterface

interface vif_default_late_explicit_if;
  logic signal;
endinterface

module sv_typeparam_virtual_interface_default;
  initial $display("PASSED");
endmodule

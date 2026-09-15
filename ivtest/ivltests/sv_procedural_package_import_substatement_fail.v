package import_substatement_pkg;
  parameter int value = 17;
endpackage

module sv_procedural_package_import_substatement_fail;
  initial begin
    if (1)
      import import_substatement_pkg::*;
    while (0)
      import import_substatement_pkg::*;
  end
endmodule

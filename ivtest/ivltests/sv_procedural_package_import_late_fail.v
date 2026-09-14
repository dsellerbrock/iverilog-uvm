package import_late_pkg;
  parameter int value = 17;
endpackage

module sv_procedural_package_import_late_fail;
  initial begin
    int result;
    result = 0;
    import import_late_pkg::*;
    $display("%0d", value);
  end
endmodule

module sv_procedural_package_import_after_null_fail;
  initial begin
    ;
    import import_late_pkg::*;
    $display("%0d", value);
  end
endmodule

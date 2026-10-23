package anon_pkg;
  program;
    task automatic package_hello();
      $display("ANON PACKAGE");
    endtask
  endprogram
endpackage

program;
  task automatic unit_hello();
    $display("ANON UNIT");
  endtask
endprogram

module anon_program_outside_fail;
  import anon_pkg::*;
  initial begin
    package_hello();
    unit_hello();
  end
endmodule

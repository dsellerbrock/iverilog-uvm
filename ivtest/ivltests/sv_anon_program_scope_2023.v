package anon_pkg;
  program;
    task automatic package_hello();
      $display("ANON PACKAGE %0t", $time);
    endtask
  endprogram
endpackage

program;
  task automatic unit_hello();
    $display("ANON UNIT %0t", $time);
  endtask
endprogram

program anon_program_scope;
  import anon_pkg::*;
  initial begin
    #1 package_hello();
    unit_hello();
  end
endprogram

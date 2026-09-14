module sv_task_lookup_forward;
  int value;
  initial begin
    set_forward();
    if (value != 11) $fatal(1, "forward task lookup failed");
  end
  task set_forward;
    value = 11;
  endtask
endmodule

module sv_task_lookup_child;
  initial begin
    #1;
    set_upward();
  end
endmodule

module sv_task_lookup_enclosing;
  int value;
  sv_task_lookup_child u_child();
  task set_upward;
    value = 22;
  endtask
  initial begin
    #2;
    if (value != 22) $fatal(1, "upward task lookup failed");
  end
endmodule

class sv_task_lookup_user;
  int value;
  task call_implicit;
    set_implicit();
  endtask
  task set_implicit;
    value = 33;
  endtask
endclass

module sv_task_lookup_resolution;
  sv_task_lookup_user obj;
  initial begin
    obj = new;
    obj.call_implicit();
    if (obj.value != 33) $fatal(1, "implicit class task lookup failed");
    #3;
    $display("PASSED");
  end
endmodule

module sv_task_lookup_compilation_unit;
  int value;
  initial begin
    set_compilation_unit(value);
    if (value != 44) $fatal(1, "compilation-unit task lookup failed");
  end
endmodule

task set_compilation_unit(output int value);
  value = 44;
endtask

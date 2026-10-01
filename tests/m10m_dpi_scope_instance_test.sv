// IEEE 1800-2017/2023 H.9: a context import uses its declaration instance.
module m10m_scope_dut;
endmodule

module m10m_scope_model #(parameter int ID = 0);
  import "DPI-C" context function int scope_check_fn(int id);
  import "DPI-C" context task scope_check_task(int id);

  initial begin
    if (scope_check_fn(ID)) $fatal(1, "DPI function scope mismatch: %0d", ID);
    scope_check_task(ID);
    #1;
    if (scope_check_fn(ID)) $fatal(1, "DPI restored scope mismatch: %0d", ID);
    $display("PASS m10m_scope_model %0d", ID);
  end
endmodule

module m10m_dpi_scope_instance_test;
  m10m_scope_dut dut();
  m10m_scope_model #(.ID(0)) u_model0();
  m10m_scope_model #(.ID(1)) u_model1();

  initial begin
    #2;
    $display("PASS m10m_dpi_scope_instance_test");
  end
endmodule

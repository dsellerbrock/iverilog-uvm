module issue889_child;
endmodule

module issue889_vpi_instance;
  issue889_child u();
  initial begin
    $probe_vpi_instance;
    $finish;
  end
endmodule

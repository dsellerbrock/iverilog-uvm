module issue1266_vpi_process_scope;
  initial begin #20; end
  initial begin #0; $probe_process_scope(); #1; $finish; end
endmodule

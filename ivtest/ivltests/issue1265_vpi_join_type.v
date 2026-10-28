module issue1265_vpi_join_type;
  initial begin
    fork : f1 begin #1; end join
    fork : f2 begin #1; end join_any
    fork : f3 begin #1; end join_none
  end
  initial begin
    #0;
    $probe_join_type;
    #2;
    $finish;
  end
endmodule

module issue1258_vpi_is_protected;
  integer x = 42;

  initial begin
    #0;
    $probe_is_protected;
    $finish;
  end
endmodule

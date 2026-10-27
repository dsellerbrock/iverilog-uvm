module ref_port_child(ref int x);
  initial begin
    if (x !== 4) $fatal(1, "ref port did not read the actual variable");
    x = 13;
  end
endmodule

module sv_module_ref_port_alias;
  int value = 4;
  ref_port_child child(value);

  initial begin
    #1;
    if (value !== 13) $fatal(1, "ref port write did not update actual");
    $display("PASS");
  end
endmodule

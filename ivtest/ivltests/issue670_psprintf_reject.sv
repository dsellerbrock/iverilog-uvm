module issue670_psprintf_reject;
  string value;
  initial begin
`ifdef INTERIOR
    value = $psprintf("%s%s", , "x", );
`elsif SFORMATF
    value = $sformatf("%s", "x", );
`else
    value = $psprintf("%s", "x", );
`endif
  end
endmodule

module sv_interconnect_reference_fail;
  interconnect link;
  wire copy;

  assign copy = link;

  initial
    $display("%b", link);
endmodule

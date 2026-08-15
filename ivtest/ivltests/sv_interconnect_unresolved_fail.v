module sv_interconnect_unresolved_observer(input interconnect unresolved_port);
  initial
    $display("%b", unresolved_port);
endmodule

module sv_interconnect_unresolved_fail;
  interconnect unresolved_link;
  sv_interconnect_unresolved_observer observer(unresolved_link);
endmodule

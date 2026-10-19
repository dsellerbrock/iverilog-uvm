module sv_covergroup_wildcard_transition;
  covergroup cg with function sample(input bit [31:0] bus_event);
    cp: coverpoint bus_event {
      wildcard bins set = (32'h0000_0000 => 32'h400?_????);
    }
  endgroup

  cg hit = new;
  cg miss = new;

  initial begin
    hit.sample(32'h0000_0000);
    hit.sample(32'h400A_1234);
    if (hit.get_inst_coverage() != 100.0)
      $fatal(1, "wildcard transition bin did not match its pattern");

    miss.sample(32'h0000_0000);
    miss.sample(32'h500A_1234);
    if (miss.get_inst_coverage() != 0.0)
      $fatal(1, "wildcard transition bin matched a different fixed prefix");

    $display("PASSED");
  end
endmodule

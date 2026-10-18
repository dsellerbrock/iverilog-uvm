module top;
  bit [1:0] v;
  covergroup cs with function sample(bit [1:0] value); coverpoint value { bins v[] = {[0:3]}; } endgroup
  cs g = new;
  initial begin
    g.sample(3); $display("%s 19.8.1.sample_with_args", g.get_inst_coverage() == 25.0 ? "PASS" : "FAIL");
    g.stop(); g.sample(2); $display("%s 19.8.stop_blocks_sampling", g.get_inst_coverage() == 25.0 ? "PASS" : "FAIL");
    g.start(); g.sample(1); $display("%s 19.8.start_resumes", g.get_inst_coverage() == 50.0 ? "PASS" : "FAIL");
  end
endmodule

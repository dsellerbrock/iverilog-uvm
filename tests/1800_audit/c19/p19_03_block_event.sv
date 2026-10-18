module top;
  int k; task automatic t1(); k++; endtask
  covergroup cb @@(end t1); coverpoint k { bins b[] = {[1:4]}; } endgroup
  cb g = new;
  initial begin t1(); t1();
    $display("%s 19.3.block_event_end cov=%f", (g.get_inst_coverage() > 49.9 && g.get_inst_coverage() < 50.1) ? "PASS" : "FAIL", g.get_inst_coverage()); end
endmodule

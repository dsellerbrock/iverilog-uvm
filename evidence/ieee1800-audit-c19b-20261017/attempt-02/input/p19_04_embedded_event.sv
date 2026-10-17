module top;
  class xyz;
    bit [3:0] m_x; local bit m_z;
    covergroup cov1 @(m_z); coverpoint m_x { bins lo = {[0:7]}; bins hi = {[8:15]}; } endgroup
    function new(); cov1 = new; endfunction
    function void poke(bit [3:0] x); m_x = x; m_z = !m_z; endfunction
  endclass
  xyz o = new;
  initial begin
    o.poke(3); #1; $display("INFO event1=%f", o.cov1.get_inst_coverage());
    $display("%s 19.4.embedded_cg_event_1", o.cov1.get_inst_coverage() == 50.0 ? "PASS" : "FAIL");
    o.poke(12); #1; $display("%s 19.4.embedded_cg_event_2", o.cov1.get_inst_coverage() == 100.0 ? "PASS" : "FAIL");
  end
endmodule

module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  function automatic bit near(real a, real b); return (a - b < 0.01) && (b - a < 0.01); endfunction
  int a, b, c, d, cov, tot; bit clk; bit [1:0] e;
  covergroup cg (int xb, yb, ref int x, y);
    coverpoint x { bins xbins[] = { [0:xb] }; }
    coverpoint y { bins ybins[] = { [0:yb] }; }
  endgroup
  covergroup ce @(posedge clk); coverpoint e { bins v[] = {[0:3]}; } endgroup
  covergroup cs with function sample(bit [1:0] v); coverpoint v { bins v[] = {[0:3]}; } endgroup
  class xyz; bit [3:0] m_x; local bit m_z;
    covergroup cov1 @(m_z); coverpoint m_x { bins lo = {[0:7]}; bins hi = {[8:15]}; } endgroup
    function new(); cov1 = new; endfunction
    function void poke(bit [3:0] x); m_x = x; m_z = !m_z; endfunction
  endclass
  cg cv1 = new(1, 2, a, b); cg cv2 = new(3, 6, c, d);
  ce gce = new; cs gcs = new; xyz o = new;
  initial begin
    void'(cv1.x.get_inst_coverage(cov, tot)); chk("19.8.cp_inst_total_2", tot == 2);
    void'(cv1.get_inst_coverage(cov, tot)); chk("19.8.cg_inst_total_5", tot == 5);
    void'(cg::x::get_coverage(cov, tot)); chk("19.8.type_cp_total_6", tot == 6);
    void'(cg::get_coverage(cov, tot)); chk("19.8.type_cg_total_16", tot == 16);
    a = 0; b = 0; cv1.sample(); a = 1; cv1.sample();
    chk("19.3.ref_arg_tracks_value", near(cv1.x.get_inst_coverage(), 100.0));
    chk("19.3.input_arg_sizes_bins", near(cv1.y.get_inst_coverage(), 100.0/3));
    chk("19.3.instances_independent", near(cv2.get_inst_coverage(), 0.0));
    $display("INFO type cg=%f cg::x=%f", cg::get_coverage(), cg::x::get_coverage());
    e = 1; #1 clk = 1; #1 clk = 0; e = 2; #1 clk = 1; #1;
    chk("19.3.clocking_event_samples", near(gce.get_inst_coverage(), 50.0));
    gcs.sample(3); chk("19.8.1.sample_with_args", near(gcs.get_inst_coverage(), 25.0));
    gcs.stop(); gcs.sample(2); chk("19.8.stop_blocks_sampling", near(gcs.get_inst_coverage(), 25.0));
    gcs.start(); gcs.sample(1); chk("19.8.start_resumes", near(gcs.get_inst_coverage(), 50.0));
    gcs.set_inst_name("inst_x"); chk("19.8.set_inst_name", gcs.option.name == "inst_x");
    o.poke(3); #1; chk("19.4.embedded_cg_event_on_local_member", near(o.cov1.get_inst_coverage(), 50.0));
    o.poke(12); #1; chk("19.4.embedded_cg_second_sample", near(o.cov1.get_inst_coverage(), 100.0));
    $display("DONE fails=%0d", fails);
  end
endmodule

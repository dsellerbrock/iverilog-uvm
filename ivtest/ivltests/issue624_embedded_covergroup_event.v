module issue624_embedded_covergroup_event;
  class sample_item;
    bit [3:0] m_x;
    bit m_z;
    covergroup cov1 @(m_z);
      coverpoint m_x {
        bins lo = {[0:7]};
        bins hi = {[8:15]};
      }
    endgroup
    function new();
      cov1 = new;
    endfunction
  endclass

  sample_item a = new;
  sample_item b = new;

  initial begin
    a.m_x = 3;
    a.m_z = 1;
    #1;
    if (a.cov1.get_inst_coverage() == 50.0
        && b.cov1.get_inst_coverage() == 0.0)
      $display("PASS embedded_event_initial");
    else
      $display("FAIL embedded_event_initial");

    a.m_x = 12;
    a.m_z = 1;
    #1;
    if (a.cov1.get_inst_coverage() == 50.0)
      $display("PASS embedded_event_same_value");
    else
      $display("FAIL embedded_event_same_value");

    b.m_x = 12;
    b.m_z = 1;
    #1;
    if (a.cov1.get_inst_coverage() == 50.0
        && b.cov1.get_inst_coverage() == 50.0)
      $display("PASS embedded_event_owner");
    else
      $display("FAIL embedded_event_owner");

    a.m_z = 0;
    #1;
    if (a.cov1.get_inst_coverage() == 100.0
        && b.cov1.get_inst_coverage() == 50.0)
      $display("PASS embedded_event_second_change");
    else
      $display("FAIL embedded_event_second_change");
  end
endmodule

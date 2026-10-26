package m_hier_pkg;
  task automatic t();
    begin : blk
      $display("%m");
    end
  endtask
endpackage

module test;
  task automatic t();
    begin : blk
      $display("%m");
    end
  endtask

  initial begin
    t();
    m_hier_pkg::t();
  end
endmodule

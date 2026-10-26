package issue1162_m_hierarchical_block_pkg;
  task automatic t;
    begin : blk
      $display("%m");
    end
  endtask
endpackage
module issue1162_m_hierarchical_block;
  task automatic t;
    begin : blk
      $display("%m");
    end
  endtask
  initial begin t(); issue1162_m_hierarchical_block_pkg::t(); end
endmodule

package pk;
  task automatic t();
    begin : blk
      $display("%m");
    end
  endtask
endpackage

module issue1162_display_hierarchical_name;
  task automatic t();
    begin : blk
      $display("%m");
    end
  endtask

  initial begin
    t();
    pk::t();
  end
endmodule

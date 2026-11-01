package issue1162_pkg;
  task t();
    begin : blk
      $display("package task: %m");
    end
  endtask
endpackage

module tb;
  task automatic t();
    begin : blk
      $display("module task: %m");
    end
  endtask

  initial begin
    t();
    issue1162_pkg::t();
  end
endmodule

module automatic_error;

reg global;

task automatic auto_task;
  reg local;
  begin : block
    local = 0;
    fork
      #1 local = 1;
      begin
        @(local || global);
        $display("PASSED");
      end
    join
  end
endtask

initial begin
  global = 0;
  auto_task;
end

endmodule

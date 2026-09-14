module sv_missing_bare_task_fail;
  initial begin
    missing_task();
    $display("UNREACHABLE");
  end
endmodule

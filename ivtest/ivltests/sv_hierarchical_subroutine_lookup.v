module test;
  child dut();
  integer result;
  initial begin
    dut.later_task(3, result);
    if ($time !== 2 || result !== 3) $fatal(1, "task timing/copyout");
    dut.later_void(4);
    void'(dut.later_value(5));
    if (dut.count !== 12) $fatal(1, "task/function effects %0d", dut.count);
    $display("PASSED");
  end
endmodule

module child;
  integer count = 0;

  task later_task(input integer add, output integer result);
    #2 count = count + add;
    result = count;
  endtask

  function void later_void(input integer add);
    count = count + add;
  endfunction

  function integer later_value(input integer add);
    count = count + add;
    return count;
  endfunction
endmodule

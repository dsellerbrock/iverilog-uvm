module child;
  int count;

  task automatic bump(input int delta, output int observed);
    #1 count += delta;
    observed = count;
  endtask

  function void mark;
    count++;
  endfunction
endmodule

class holder;
  int count;
  task bump;
    count++;
  endtask
endclass

module test;
  child dut[1:0]();
  for (genvar g = 0; g < 2; g++) begin: gblk
    int count;
    task automatic bump(input int delta, output int observed);
      #1 count += delta;
      observed = count;
    endtask
  end

  holder objects[2];
  int object_index;
  int observed;

  initial begin
    objects[0] = new;
    objects[1] = new;
    object_index = 1;

    dut[1].bump(3, observed);
    if (observed != 3 || dut[1].count != 3 || dut[0].count != 0)
      $fatal(1, "instance-array task effects are wrong");

    dut[0].mark();
    if (dut[0].count != 1)
      $fatal(1, "instance-array void function did not execute");

    gblk[0].bump(4, observed);
    if (observed != 4 || gblk[0].count != 4 || gblk[1].count != 0)
      $fatal(1, "generate-scope task effects are wrong");

    objects[object_index].bump();
    if (objects[1].count != 1 || objects[0].count != 0)
      $fatal(1, "indexed object method dispatch regressed");
    $display("PASSED");
  end
endmodule

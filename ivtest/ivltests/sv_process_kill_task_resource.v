// Killing a task-owned descendant must cancel its blocked mailbox waiter.
module main;
  mailbox #(int) box;
  process parent, child;
  bit consumed;
  int value;
  task automatic work;
    fork
      begin
        int item;
        child=process::self();
        box.get(item);
        consumed=1;
      end
    join_none
    #100;
  endtask
  initial begin
    box=new;
    fork begin parent=process::self(); work(); end join_none
    #1;
    if (child.status()!=process::WAITING) $fatal(1,"reader did not block");
    parent.kill();
    box.put(73);
    #1;
    if (consumed || child.status()!=process::KILLED || box.num()!=1)
      $fatal(1,"killed reader consumed resource");
    box.get(value);
    if (value!=73 || box.num()!=0) $fatal(1,"resource was not preserved");
    $display("PASSED"); $finish(0);
  end
endmodule

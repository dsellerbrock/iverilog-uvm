// Killing self inside a synchronous task also kills its forked children.
module main;
  process parent, child;
  int ticks, saved;
  bit escaped;
  task automatic stop_parent;
    parent.kill();
    escaped=1;
  endtask
  task automatic work;
    fork
      begin child=process::self(); forever begin #1; ticks++; end end
    join_none
    #5;
    stop_parent();
    escaped=1;
  endtask
  initial begin
    parent=process::self();
    work();
    escaped=1;
  end
  initial begin
    #10;
    if (escaped || parent.status()!=process::KILLED || child.status()!=process::KILLED)
      $fatal(1,"self kill failed: escape=%0d parent=%0d child=%0d",escaped,parent.status(),child.status());
    saved=ticks;
    #5;
    if (ticks!=saved) $fatal(1,"child continued after self kill");
    $display("PASSED"); $finish(0);
  end
endmodule

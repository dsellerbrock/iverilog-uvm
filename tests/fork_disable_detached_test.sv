// Regression: `disable <named block>` must kill detached join_any/join_none
// children spawned by an UNNAMED fork beneath that block (ivtest
// fork_join_dis). The fork used to synthesize a $unm_blk scope for every
// unnamed fork; children forked into that child scope, so %disable of the
// enclosing block's scope never reached them and they kept running.
// Upstream never creates that scope — the empty unnamed fork scope is now
// elided, except inside a task or function: in a function it distinguishes
// deferred task calls in a forked process from an illegal direct call, and
// in a task it keeps the runtime from mistaking a real forked process for
// a compiled task call that shares the caller's process identity
// (process::self() aliasing broke the UVM sequencer handshake).
module fork_disable_detached_test;
  reg [1:0] a, b;
  bit ok_fn;

  // join_any children killed by disabling the enclosing named BLOCK.
  initial begin : blk
    fork
      #1 a[0] = 1'b1;
      #3 a[1] = 1'b1;
    join_any
    disable blk;
  end

  // Detached child killed by an EXTERNAL lexical disable after the
  // parent block has already ended.
  initial begin : blk2
    fork
      #1 b[0] = 1'b1;
      #3 b[1] = 1'b1;
    join_any
  end

  // The function exception must survive: a task call inside a
  // fork...join_none in a function is a deferred (legal) call.
  task automatic tick(output bit done);
    done = 1'b1;
  endtask
  function void kick();
    fork
      tick(ok_fn);
    join_none
  endfunction

  initial begin
    a = 2'b00; b = 2'b00;
    kick();
    #2 disable blk2;
    #3;
    if (a === 2'b01 && b === 2'b01 && ok_fn)
      $display("PASS: disable kills detached unnamed-fork children");
    else
      $display("FAIL: a=%b b=%b ok_fn=%b", a, b, ok_fn);
    $finish;
  end
endmodule

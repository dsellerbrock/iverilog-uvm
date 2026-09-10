// IEEE 1800-2017/2023 9.7: task/named frames are part of the calling
// process; forked children inside them must be reached by parent.kill().
module main;
  process parents[3], children[6];
  int ticks[6], saved[6], sibling_ticks, saved_sibling;

  task automatic workers(input int index);
    fork
      begin children[index]=process::self(); forever begin #1; ticks[index]++; end end
      begin children[index+1]=process::self(); forever begin #1; ticks[index+1]++; end end
    join_none
    #100;
  endtask

  task automatic nested(input int index);
    begin : frame
      int local_value;
      local_value=index;
      workers(local_value);
    end
  endtask

  task static static_frame;
    workers(2);
  endtask

  initial begin
    fork
      begin parents[0]=process::self(); nested(0); end
      begin parents[1]=process::self(); static_frame(); end
      begin
        parents[2]=process::self();
        fork
          nested(4);
          #100;
        join_any
      end
      forever begin #1; sibling_ticks++; end
    join_none
    #5;
    foreach (parents[i]) parents[i].kill();
    foreach (children[i]) begin
      if (children[i].status()!=process::KILLED)
        $fatal(1,"descendant %0d survived with state %0d",i,children[i].status());
      saved[i]=ticks[i];
    end
    saved_sibling=sibling_ticks;
    #5;
    foreach (children[i])
      if (ticks[i]!=saved[i]) $fatal(1,"descendant %0d continued",i);
    if (sibling_ticks<=saved_sibling) $fatal(1,"unrelated sibling killed");
    $display("PASSED"); $finish(0);
  end
endmodule

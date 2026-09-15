class joint_element_mixed_leaf; rand bit value; endclass
class joint_element_mixed;
  rand bit first;
  rand bit values[2];
  rand bit tail;
  rand joint_element_mixed_leaf child;
  int posts;
  function new; child=new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c {
    solve first before values[0];
    solve values[0] before values[1];
  }
  constraint fiber {
    values[0] <= first;
    values[1] <= values[0];
    child.value == values[1];
  }
endclass
module sv_randomize_joint_element_order_mixed;
  joint_element_mixed item=new, control=new, stats=new;
  string root_state,child_state;
  bit f,v0,v1,t,before_f,before_v0,before_v1,before_t,before_child;
  int before_posts;
  int outcomes[4];
  initial begin
    stats.srandom(32'h870102);
    repeat (4096) begin
      if (!stats.randomize() || stats.values[0]>stats.first ||
          stats.values[1]>stats.values[0] ||
          stats.child.value!=stats.values[1]) $fatal(1,"mixed relation");
      if (!stats.first) outcomes[0]++;
      else if (!stats.values[0]) outcomes[1]++;
      else if (!stats.values[1]) outcomes[2]++;
      else outcomes[3]++;
    end
    if (outcomes[0]<1850 || outcomes[0]>2250 ||
        outcomes[1]<850 || outcomes[1]>1200 ||
        outcomes[2]<400 || outcomes[2]>650 ||
        outcomes[3]<400 || outcomes[3]>650)
      $fatal(1,"mixed transitive marginals %0d %0d %0d %0d",
             outcomes[0],outcomes[1],outcomes[2],outcomes[3]);
    item.srandom(32'h870002); item.child.srandom(32'h87c002);
    control.srandom(32'h870002); control.child.srandom(32'h87c002);
    if (!control.randomize()) $fatal(1,"control");
    f=control.first;v0=control.values[0];v1=control.values[1];t=control.tail;
    before_f=item.first; before_v0=item.values[0];
    before_v1=item.values[1]; before_t=item.tail;
    before_child=item.child.value; before_posts=item.posts;
    root_state=item.get_randstate(); child_state=item.child.get_randstate();
    if (item.randomize() with { first==0; values[1]==1; } ||
        item.posts!=before_posts || item.first!=before_f ||
        item.values[0]!=before_v0 || item.values[1]!=before_v1 ||
        item.tail!=before_t || item.child.value!=before_child ||
        item.get_randstate()!=root_state ||
        item.child.get_randstate()!=child_state)
      $fatal(1,"mixed UNSAT rollback");
    if (!item.randomize() || item.first!=f || item.values[0]!=v0 ||
        item.values[1]!=v1 || item.tail!=t || item.child.value!=v1 || item.posts!=1)
      $fatal(1,"mixed transitive replay");
    $display("PASSED");
  end
endmodule

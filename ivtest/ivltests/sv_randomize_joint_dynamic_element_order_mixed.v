class joint_dynamic_mixed_leaf; rand bit value; endclass
class joint_dynamic_mixed;
  rand bit scalar;
  rand bit values[];
  rand joint_dynamic_mixed_leaf child;
  int wanted=1,posts;
  function new; values=new[3]; child=new; endfunction
  function void post_randomize; posts++; endfunction
  constraint size_c { values.size()==wanted; }
  constraint order_c { solve scalar before values[0]; }
  constraint fiber { values[0]<=scalar; child.value==values[0]; }
endclass
module sv_randomize_joint_dynamic_element_order_mixed;
  joint_dynamic_mixed item=new,control=new;
  string rs,cs; bit s,v,c; int p;
  initial begin
    item.values[0]=1; item.values[1]=1; item.values[2]=1;
    control.values[0]=1; control.values[1]=1; control.values[2]=1;
    item.srandom(32'h880002);item.child.srandom(32'h88c002);
    control.srandom(32'h880002);control.child.srandom(32'h88c002);
    if (!control.randomize()) $fatal(1,"control");
    s=control.scalar;v=control.values[0];c=control.child.value;
    rs=item.get_randstate();cs=item.child.get_randstate();p=item.posts;
    item.wanted=0;
    if (item.randomize() || item.values.size()!=3 || item.values[0]!=1 ||
        item.values[1]!=1 || item.values[2]!=1 || item.child.value ||
        item.posts!=p || item.get_randstate()!=rs || item.child.get_randstate()!=cs)
      $fatal(1,"size-zero ordered element rollback");
    item.wanted=1;
    if (!item.randomize() || item.values.size()!=1 || item.scalar!=s ||
        item.values[0]!=v || item.child.value!=c || item.posts!=p+1)
      $fatal(1,"size-one replay");
    item.values[0]=1; item.values[0].rand_mode(0);
    repeat(8) if (!item.randomize() || item.values.size()!=1 ||
                 item.values[0]!=1 || item.child.value!=1)
      $fatal(1,"frozen dynamic element");
    $display("PASSED");
  end
endmodule

class joint_dynamic_fail_leaf; rand bit value; endclass
class joint_dynamic_wide_index;
  rand bit values[]; rand bit scalar; int posts;
  function new;values=new[2];endfunction
  function void post_randomize;posts++;endfunction
  constraint size_c {values.size()==1;}
  constraint order_c {solve values[64'h1_0000_0000] before scalar;}
  constraint coupled {scalar==values[0];}
endclass
class joint_dynamic_negative_index;
  rand bit values[]; rand bit scalar; int posts;
  function new;values=new[2];endfunction
  function void post_randomize;posts++;endfunction
  constraint size_c {values.size()==1;}
  constraint order_c {solve values[-1] before scalar;}
  constraint coupled {scalar==values[0];}
endclass
class joint_dynamic_oob;
  rand bit values[]; rand joint_dynamic_fail_leaf child; int posts;
  function new;values=new[3];child=new;endfunction
  function void post_randomize;posts++;endfunction
  constraint size_c {values.size()==1;}
  constraint order_c {solve values[0] before values[1];}
  constraint coupled {child.value==values[0];}
endclass
class joint_dynamic_ambiguous;
  rand bit values[]; rand bit scalar; rand joint_dynamic_fail_leaf child; int posts;
  function new;values=new[3];child=new;endfunction
  function void post_randomize;posts++;endfunction
  constraint size_c {values.size() inside {[1:2]};}
  constraint order_c {solve values[0] before scalar;}
  constraint coupled {scalar==values[0];child.value==scalar;}
endclass
class joint_dynamic_cap;
  rand bit values[]; rand joint_dynamic_fail_leaf child; int posts;
  function new;values=new[11];child=new;endfunction
  function void post_randomize;posts++;endfunction
  constraint size_c {values.size()==11;}
  constraint order_c {solve values[0] before values[1];}
  constraint coupled {
    child.value==(values[0]^values[1]^values[2]^values[3]^values[4]^
                  values[5]^values[6]^values[7]^values[8]^values[9]^
                  values[10]);
  }
endclass
module sv_randomize_joint_dynamic_element_order_fail;
 joint_dynamic_oob oob=new;joint_dynamic_wide_index wide=new;
 joint_dynamic_negative_index negative=new;
 joint_dynamic_ambiguous ambiguous=new;joint_dynamic_cap cap=new;
 string os,ocs,ws,ns,as,acs,caps,capcs;bit cap_changed;
 initial begin
  oob.values[0]=1;oob.values[1]=1;oob.values[2]=1;
  ambiguous.values[0]=1;ambiguous.values[1]=1;ambiguous.values[2]=1;
  wide.values[0]=1;wide.values[1]=1;negative.values[0]=1;negative.values[1]=1;
  oob.srandom(32'h88fa11);oob.child.srandom(32'h88fc11);
  wide.srandom(32'h88fa14);negative.srandom(32'h88fa15);
  ambiguous.srandom(32'h88fa12);ambiguous.child.srandom(32'h88fc12);
  cap.srandom(32'h88fa13);cap.child.srandom(32'h88fc13);
  os=oob.get_randstate();ocs=oob.child.get_randstate();ws=wide.get_randstate();ns=negative.get_randstate();
  as=ambiguous.get_randstate();acs=ambiguous.child.get_randstate();
  caps=cap.get_randstate();capcs=cap.child.get_randstate();
  if(oob.randomize()||oob.values.size()!=3||!oob.values[0]||!oob.values[1]||!oob.values[2]||oob.child.value||oob.posts||oob.get_randstate()!=os||oob.child.get_randstate()!=ocs)$fatal(1,"dynamic OOB rollback");
  if(wide.randomize()||wide.values.size()!=2||!wide.values[0]||!wide.values[1]||wide.scalar||wide.posts||wide.get_randstate()!=ws)$fatal(1,"dynamic wide-index rollback");
  if(negative.randomize()||negative.values.size()!=2||!negative.values[0]||!negative.values[1]||negative.scalar||negative.posts||negative.get_randstate()!=ns)$fatal(1,"dynamic negative-index rollback");
  if(ambiguous.randomize()||ambiguous.values.size()!=3||!ambiguous.values[0]||!ambiguous.values[1]||!ambiguous.values[2]||ambiguous.scalar||ambiguous.child.value||ambiguous.posts||ambiguous.get_randstate()!=as||ambiguous.child.get_randstate()!=acs)$fatal(1,"dynamic size proof rollback");
  if(cap.randomize())cap_changed=1;foreach(cap.values[i])cap_changed|=cap.values[i];
  if(cap_changed||cap.values.size()!=11||cap.child.value||cap.posts||cap.get_randstate()!=caps||cap.child.get_randstate()!=capcs)$fatal(1,"dynamic cap rollback");
  $display("PASSED");
 end
endmodule

class joint_queue_mixed_leaf;rand bit value;endclass
class joint_queue_mixed;
 rand bit scalar;rand bit values[$:2];rand joint_queue_mixed_leaf child;joint_queue_mixed_leaf alias_child;int wanted=1,posts;
 function new;values.push_back(1);values.push_back(1);values.push_back(1);child=new;alias_child=child;endfunction
 function void post_randomize;posts++;endfunction
 constraint size_c {values.size()==wanted;}
 constraint order_c {solve scalar before values[0];}
 constraint fiber {values[0]<=scalar;child.value==values[0];alias_child.value==values[0];}
endclass
module sv_randomize_joint_queue_element_order_mixed;
 joint_queue_mixed item=new,control=new;string rs,cs;bit s,v,c;int p;
 initial begin item.srandom(32'h890002);item.child.srandom(32'h89c002);control.srandom(32'h890002);control.child.srandom(32'h89c002);
  if(!control.randomize())$fatal(1,"control");s=control.scalar;v=control.values[0];c=control.child.value;
  rs=item.get_randstate();cs=item.child.get_randstate();p=item.posts;item.wanted=0;
  if(item.randomize()||item.values.size()!=3||!item.values[0]||!item.values[1]||!item.values[2]||item.child.value||item.posts!=p||item.get_randstate()!=rs||item.child.get_randstate()!=cs)$fatal(1,"queue zero rollback");
  item.wanted=1;if(!item.randomize()||item.values.size()!=1||item.scalar!=s||item.values[0]!=v||item.child.value!=c||item.posts!=p+1)$fatal(1,"queue replay");
  item.values[0]=1;item.values[0].rand_mode(0);item.values.push_back(0);repeat(8)if(!item.randomize()||item.values.size()!=1||item.child!=item.alias_child||!item.values[0]||!item.child.value)$fatal(1,"queue retained mode");
  $display("PASSED");end
endmodule

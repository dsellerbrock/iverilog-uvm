class joint_queue_nonrandom;
  bit values[$];
  rand bit scalar;
  function new;values.push_back(0);endfunction
  constraint order_c {solve scalar before values[0];}
endclass
module sv_randomize_joint_queue_element_order_nonrandom_fail;
 joint_queue_nonrandom item=new;
 initial void'(item.randomize());
endmodule

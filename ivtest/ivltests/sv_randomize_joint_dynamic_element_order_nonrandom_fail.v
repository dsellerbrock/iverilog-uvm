class joint_dynamic_nonrandom;
  bit values[];
  rand bit scalar;
  function new;values=new[1];endfunction
  constraint order_c {solve scalar before values[0];}
endclass
module sv_randomize_joint_dynamic_element_order_nonrandom_fail;
 joint_dynamic_nonrandom item=new;
 initial void'(item.randomize());
endmodule

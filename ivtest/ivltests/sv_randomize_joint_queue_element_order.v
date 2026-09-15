class joint_queue_order_leaf; rand bit value; endclass
class joint_queue_order_pair;
  rand bit values[$]; rand joint_queue_order_leaf child; int wanted=2;
  function new; values.push_back(0); values.push_back(0); child=new; endfunction
  constraint size_c {values.size()==wanted;}
  constraint order_c {solve values[0] before values[1];}
  constraint fiber {values[1]<=values[0];child.value==values[1];}
endclass
class joint_queue_signed_pair;
  rand bit signed [3:0] values[$:3]; rand joint_queue_order_leaf child;
  function new;values.push_back(0);values.push_back(0);child=new;endfunction
  constraint size_c {values.size()==2;}
  constraint order_c {solve values[0] before values[1];}
  constraint domain_c {(values[0]==4'shf||values[0]==4'sh1);values[1]<=values[0];child.value==(values[1]!=0);}
endclass
typedef enum bit[1:0]{QUEUE_E0,QUEUE_E1,QUEUE_E2,QUEUE_E3} joint_queue_enum_t;
class joint_queue_enum_pair;
  rand joint_queue_enum_t values[$]; rand joint_queue_order_leaf child;
  function new;values.push_back(QUEUE_E0);values.push_back(QUEUE_E0);child=new;endfunction
  constraint size_c {values.size()==2;}
  constraint order_c {solve values[0] before values[1];}
  constraint fiber {values[1]<=values[0];child.value==(values[1]!=QUEUE_E0);}
endclass
module sv_randomize_joint_queue_element_order;
 joint_queue_order_pair item=new;joint_queue_signed_pair signed_item=new;joint_queue_enum_pair enum_item=new;
 int n00,n10,n11;
 initial begin item.srandom(32'h890001);repeat(4096)begin
  if(!item.randomize()||item.values.size()!=2||item.values[1]>item.values[0]||item.child.value!=item.values[1])$fatal(1,"queue relation");
  if(!item.values[0])n00++;else if(!item.values[1])n10++;else n11++;
 end
 if(n00<1850||n00>2250||n10<850||n10>1200||n11<850||n11>1200)$fatal(1,"queue marginals %0d %0d %0d",n00,n10,n11);
 item.values.push_back(1);item.values.push_back(1);if(!item.randomize()||item.values.size()!=2)$fatal(1,"queue shrink");
 item.values.delete();if(!item.randomize()||item.values.size()!=2||item.values[1]>item.values[0])$fatal(1,"queue grow");
 repeat(64)begin
  if(!signed_item.randomize()||signed_item.values[1]>signed_item.values[0]||signed_item.child.value!=(signed_item.values[1]!=0))$fatal(1,"signed queue order");
  if(!enum_item.randomize()||enum_item.values[1]>enum_item.values[0]||enum_item.child.value!=(enum_item.values[1]!=QUEUE_E0))$fatal(1,"enum queue order");
 end
 $display("PASSED");end
endmodule

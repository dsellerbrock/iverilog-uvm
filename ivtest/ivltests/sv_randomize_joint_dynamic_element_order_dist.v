class joint_dynamic_dist_leaf; rand bit value; endclass
class joint_dynamic_dist;
  rand bit values[];
  rand joint_dynamic_dist_leaf child;
  function new;values=new[2];child=new;endfunction
  constraint size_c {values.size()==2;}
  constraint order_c {solve values[0] before values[1];}
  constraint weights {values[0] dist {0:=1,1:=3};}
  constraint fiber {values[1]<=values[0];child.value==values[1];}
endclass
module sv_randomize_joint_dynamic_element_order_dist;
 joint_dynamic_dist item=new;int first,n10,n11;
 initial begin item.srandom(32'h880003);repeat(4096)begin
  if(!item.randomize()||item.values.size()!=2||item.values[1]>item.values[0]||item.child.value!=item.values[1])$fatal(1,"dynamic dist relation");
  first+=item.values[0];n10+=item.values[0]&&!item.values[1];n11+=item.values[0]&&item.values[1];
 end
 if(first<2920||first>3220||n10<1350||n10>1700||n11<1350||n11>1700)$fatal(1,"dynamic dist %0d %0d %0d",first,n10,n11);
 $display("PASSED");end
endmodule

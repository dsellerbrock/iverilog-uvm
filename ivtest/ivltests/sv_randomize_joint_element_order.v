class joint_element_leaf;
  rand bit value;
endclass
class joint_element_pair;
  rand bit value[3:2];
  rand joint_element_leaf child;
  joint_element_leaf alias_child;
  function new; child=new; alias_child=child; endfunction
  constraint order_c { solve value[3] before value[2]; }
  constraint fiber { value[2] <= value[3]; alias_child.value == value[2]; }
endclass
class joint_element_single;
  rand bit scalar;
  rand bit value[1];
  rand joint_element_leaf child;
  function new; child=new; endfunction
  constraint order_c { solve scalar before value[0]; }
  constraint fiber { value[0] <= scalar; child.value == value[0]; }
endclass
module sv_randomize_joint_element_order;
  joint_element_pair item=new;
  joint_element_single single=new;
  int n00,n10,n11;
  initial begin
    item.srandom(32'h870001); item.child.srandom(32'h87c001);
    repeat (4096) begin
      if (!item.randomize() || item.child!=item.alias_child ||
          item.value[2]>item.value[3] || item.child.value!=item.value[2])
        $fatal(1,"selected element relation");
      if (!item.value[3]) n00++;
      else if (!item.value[2]) n10++;
      else n11++;
    end
    // The first element is uniform; the second is uniform in its fiber.
    if (n00<1850 || n00>2250 || n10<850 || n10>1200 || n11<850 || n11>1200)
      $fatal(1,"element marginals %0d %0d %0d",n00,n10,n11);
    item.value[3]=1; item.value[2]=0; item.value[3].rand_mode(0);
    repeat (16) if (!item.randomize() || item.value[3]!=1 ||
                    item.value[2]>item.value[3])
      $fatal(1,"frozen ordered element");
    repeat (16) if (!single.randomize() || single.value[0]>single.scalar ||
                    single.child.value!=single.value[0])
      $fatal(1,"one-element unpacked array ordering");
    $display("PASSED");
  end
endmodule

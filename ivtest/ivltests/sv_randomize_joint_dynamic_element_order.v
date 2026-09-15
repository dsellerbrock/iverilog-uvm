class joint_dynamic_order_leaf; rand bit value; endclass
class joint_dynamic_order_pair;
  rand bit values[];
  rand joint_dynamic_order_leaf child;
  joint_dynamic_order_leaf alias_child;
  int wanted=2;
  function new; values=new[0]; child=new; alias_child=child; endfunction
  constraint size_c { values.size()==wanted; }
  constraint order_c { solve values[0] before values[1]; }
  constraint fiber { values[1]<=values[0]; alias_child.value==values[1]; }
endclass
class joint_dynamic_signed_pair;
  rand bit signed [3:0] values[];
  rand joint_dynamic_order_leaf child;
  function new; values=new[0]; child=new; endfunction
  constraint size_c { values.size()==2; }
  constraint order_c { solve values[0] before values[1]; }
  constraint domain_c { (values[0]==4'shf || values[0]==4'sh1);
                        values[1]<=values[0]; child.value==(values[1]!=0); }
endclass
typedef enum bit [1:0] {DYN_E0,DYN_E1,DYN_E2,DYN_E3} joint_dynamic_enum_t;
class joint_dynamic_enum_pair;
  rand joint_dynamic_enum_t values[];
  rand joint_dynamic_order_leaf child;
  function new; values=new[0]; child=new; endfunction
  constraint size_c { values.size()==2; }
  constraint order_c { solve values[0] before values[1]; }
  constraint domain_c { values[1]<=values[0]; child.value==(values[1]!=DYN_E0); }
endclass
module sv_randomize_joint_dynamic_element_order;
  joint_dynamic_order_pair item=new;
  joint_dynamic_signed_pair signed_item=new;
  joint_dynamic_enum_pair enum_item=new;
  int n00,n10,n11;
  initial begin
    item.srandom(32'h880001);
    repeat (4096) begin
      if (!item.randomize() || item.values.size()!=2 ||
          item.child!=item.alias_child || item.values[1]>item.values[0] ||
          item.child.value!=item.values[1]) $fatal(1,"dynamic relation");
      if (!item.values[0]) n00++;
      else if (!item.values[1]) n10++;
      else n11++;
    end
    if (n00<1850 || n00>2250 || n10<850 || n10>1200 || n11<850 || n11>1200)
      $fatal(1,"dynamic marginals %0d %0d %0d",n00,n10,n11);
    item.values=new[4]; item.values[2]=1; item.values[3]=1;
    if (!item.randomize() || item.values.size()!=2 ||
        item.values[1]>item.values[0]) $fatal(1,"shrink to proved size");
    item.values=new[0];
    if (!item.randomize() || item.values.size()!=2 ||
        item.values[1]>item.values[0]) $fatal(1,"grow to proved size");
    repeat (64) begin
      if (!signed_item.randomize() || signed_item.values.size()!=2 ||
          signed_item.values[1]>signed_item.values[0] ||
          signed_item.child.value!=(signed_item.values[1]!=0))
        $fatal(1,"signed dynamic ordering");
      if (!enum_item.randomize() || enum_item.values.size()!=2 ||
          enum_item.values[1]>enum_item.values[0] ||
          enum_item.child.value!=(enum_item.values[1]!=DYN_E0))
        $fatal(1,"enum dynamic ordering");
    end
    $display("PASSED");
  end
endmodule

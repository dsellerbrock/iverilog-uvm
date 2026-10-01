class l111_zero_leaf; randc bit cyc; endclass
class l111_zero_item; rand bit sel,dep;rand l111_zero_leaf leaf;
 constraint l {sel==leaf.cyc;dep==sel;} constraint w {sel dist {0:=0,1:=1};} constraint o {solve sel before dep;}
 function new;leaf=new;endfunction endclass
module sv_joint_coupled_randc_ordered_zero_weight;initial begin l111_zero_item t;t=new;
 repeat(4)begin if(!t.randomize())$fatal(1,"randomize");if(t.leaf.cyc!=1||t.sel!=1||t.dep!=1)$fatal(1,"zero weight admitted");end
 $display("PASSED");$finish(0);end endmodule

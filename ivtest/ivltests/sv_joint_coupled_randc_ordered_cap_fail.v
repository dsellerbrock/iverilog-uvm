class l111_cap_leaf; randc bit cyc; endclass
class l111_cap_item; rand bit [10:0] wide;rand bit dep;rand l111_cap_leaf leaf;
 constraint l {wide[0]==leaf.cyc;dep==wide[0];} constraint o {solve wide before dep;}
 function new;leaf=new;endfunction endclass
module sv_joint_coupled_randc_ordered_cap_fail;initial begin l111_cap_item t;t=new;if(t.randomize())$fatal(1,"cap succeeded");$display("PASSED");$finish(0);end endmodule

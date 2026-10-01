class l111_multi_leaf; randc bit a,b; endclass
class l111_multi_item; rand bit sel,dep; rand l111_multi_leaf leaf;
 constraint l {sel==(leaf.a^leaf.b);dep==sel;} constraint w {sel dist {0:=1,1:=2};} constraint o {solve sel before dep;}
 function new;leaf=new;endfunction endclass
module sv_joint_coupled_randc_ordered_multi_fail; initial begin l111_multi_item t;t=new;t.sel=0;t.dep=1;t.leaf.a=0;t.leaf.b=1;
 if(t.randomize())$fatal(1,"unsupported succeeded");if(t.sel!=0||t.dep!=1||t.leaf.a!=0||t.leaf.b!=1)$fatal(1,"rollback");$display("PASSED");$finish(0);end endmodule

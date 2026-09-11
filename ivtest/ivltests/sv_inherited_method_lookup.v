// IEEE 1800-2017/2023 8.13, 23.8.1.
package p;
 function int enabled(); return 7; endfunction
 task bump(); $fatal(1,"package task selected"); endtask
 class base;
  int value;
  function int enabled(); return value; endfunction
  task bump(); value++; endtask
  virtual function int overridden(); return value; endfunction
 endclass
 class child extends base;
  function int check(); return enabled(); endfunction
  function int explicit_package(); return p::enabled(); endfunction
  function int virtual_check(); return overridden(); endfunction
  task update(); bump(); endtask
 endclass
 class override_child extends child;
  function int enabled(); return value+10; endfunction
 endclass
 class leaf extends child;
  function int overridden(); return value+100; endfunction
 endclass
endpackage
module sv_inherited_method_lookup;
 p::child c; p::leaf l; p::override_child o;
 initial begin
 c=new; c.value=42;
 if(c.check()!=42 || c.explicit_package()!=7) $fatal(1,"receiver or package");
 c.update(); if(c.check()!=43) $fatal(1,"task receiver");
 l=new; l.value=9;
 if(l.virtual_check()!=109) $fatal(1,"virtual receiver");
 o=new; o.value=5;
 if(o.check()!=5 || o.enabled()!=15) $fatal(1,"nonvirtual lexical binding");
 $display("PASSED");
 end
endmodule

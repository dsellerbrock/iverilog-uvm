// IEEE 1800-2017/2023 8.18.
package p;
 int calls;
 function void hidden_statement(); calls++; endfunction
 function int secret(); return 7; endfunction
 function int guarded(); return 8; endfunction
 function int outside(); return 9; endfunction
 class base;
  int value;
  local function void hidden_statement(); $fatal(1,"private statement selected"); endfunction
  local function int secret(); return value+100; endfunction
  protected function int guarded(); return value+200; endfunction
  extern local function int outside();
  function int own_secret(); return secret(); endfunction
 endclass
 function int base::outside(); return value+300; endfunction
 class child extends base;
  task call_statement(); hidden_statement(); endtask
  function int check(); return secret(); endfunction
  function int protected_check(); return guarded(); endfunction
  function int extern_check(); return outside(); endfunction
 endclass
endpackage
module sv_inherited_method_visibility;
 p::child c;
 initial begin
 c=new; c.value=42;
 if(c.check()!=7 || c.own_secret()!=142 || c.protected_check()!=242 || c.extern_check()!=9)
   $fatal(1,"method visibility");
 c.call_statement();
 if(p::calls!=1) $fatal(1,"package statement count");
 $display("PASSED");
 end
endmodule

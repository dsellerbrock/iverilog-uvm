// IEEE 1800-2017/2023 8.25: a generic class is not itself a type.
package registration;
  int calls[6];
  function automatic int register_type(int id);
    calls[id]++;
    return id;
  endfunction
  class Unused#(type T=int);
    static int value=register_type(0);
  endclass
  class Registry#(int ID=1);
    static int value=register_type(ID);
    const static int marker=17;
  endclass
  class Ordinary;
    static int value=register_type(4);
  endclass
  class Derived extends Registry#(5); endclass
  typedef Registry#(2) repeated_type;
endpackage
module sv_generic_master_static_init;
  import registration::*;
  Registry default_type;
  Registry#(1) explicit_default;
  Registry#(2) concrete;
  repeated_type repeated;
  Derived derived;
  initial begin
    // This is a static-only concrete use, with no object allocation.
    if(Registry#(2)::marker!=17) $fatal(1,"const initializer analysis");
    if(Registry#(3)::value!=3) $fatal(1,"static-only specialization");
    if(calls[0]!=0) $fatal(1,"unused generic master initialized");
    for(int i=1;i<=5;i++)
      if(calls[i]!=1) $fatal(1,"registration %0d ran %0d times",i,calls[i]);
    default_type=new;
    explicit_default=new;
    concrete=new;
    repeated=new;
    derived=new;
    for(int i=1;i<=5;i++)
      if(calls[i]!=1) $fatal(1,"object construction repeated static init");
    if(Ordinary::value!=4) $fatal(1,"ordinary class initialization");
    $display("PASSED");
  end
endmodule

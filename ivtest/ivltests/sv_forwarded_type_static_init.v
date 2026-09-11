// IEEE 1800-2017/2023 8.25: unresolved type forwarding is not a concrete type.
package forwarded_init;
  int calls[65];
  function automatic int register_type(int width);
    calls[width]++;
    return width;
  endfunction
  class Record#(type T=int);
    static int registration=register_type($bits(T));
    const static int marker=17;
  endclass
  class Forward#(type T=byte);
    Record#(T) item;
  endclass
  class Outer#(type T=shortint);
    Forward#(T) item;
  endclass
  class Dependent#(type T=int, type R=T);
    static int registration=register_type(32+$bits(R));
  endclass
  class DependentForward#(type T=byte);
    Dependent#(T) item;
  endclass
  // The concrete key can be created while elaborating a template and later
  // reused by a real use. Blanket seed_derived suppression would lose it.
  class ConcreteFromTemplate#(type T=int);
    Record#(bit[5:0]) concrete;
  endclass
  class Shadow#(type T=byte);
    static function int sample();
      typedef bit[10:0] T;
      return Record#(T)::registration;
    endfunction
  endclass
endpackage
module sv_forwarded_type_static_init;
  import forwarded_init::*;
  Record#(bit) direct;
  Outer#(bit[3:0]) forwarded;
  Record#(bit[3:0]) repeated;
  Record#(bit[5:0]) concrete;
  DependentForward#(bit[8:0]) dependent;
  initial begin
    if(Shadow#(bit)::sample()!=11) $fatal(1,"shadowed concrete type");
    if(Record#(bit[5:0])::registration!=6 || Record#(bit)::marker!=17)
      $fatal(1,"concrete reuse or const analysis");
    for(int i=0;i<65;i++) begin
      if(i==1 || i==4 || i==6 || i==11 || i==41) begin
        if(calls[i]!=1) $fatal(1,"concrete %0d initialized %0d times",i,calls[i]);
      end else if(calls[i]!=0) $fatal(1,"symbolic %0d initialized",i);
    end
    $display("PASSED");
  end
endmodule

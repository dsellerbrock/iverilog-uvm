// IEEE 1800-2017/2023 8.25: matching effective type parameters select one type.
package default_identity;
  class A; endclass
  class B; endclass
  class C; endclass
  class Base; endclass
  typedef B B_alias;
  class Pair#(type T=A, type U=B) extends Base;
    static int count;
    int value;
  endclass
  typedef B B_array[2];
  class ArrayDefault#(type T=A, type U=B_array);
    U items;
  endclass
  class Box#(type T=A);
    T item;
  endclass
  // A nested dependent default must not be evaluated in the package scope
  // merely to probe the specialization cache.
  class Nested#(type T=A, type U=Box#(T));
    U box;
    function new(); box=new; box.item=new; endfunction
  endclass
  class Forward#(type T=A);
    typedef Pair#(T) pair_type;
    static function pair_type make();
      pair_type p;
      p=new;
      return p;
    endfunction
  endclass
endpackage
package other_identity;
  class B; endclass
  class Pair#(type T=default_identity::A, type U=default_identity::B)
    extends default_identity::Base;
  endclass
endpackage
module sv_class_independent_defaults;
  import default_identity::*;
  initial begin
    Pair#(A) omitted;
    Pair#(A,B) explicit_pair;
    Pair#(.U(B_alias),.T(A)) named_pair;
    Pair#() defaults;
    Pair#(C) different;
    Pair#(A,C) different_second;
    Pair#(A,other_identity::B) other_argument;
    other_identity::Pair#(A,B) other_owner;
    Base base;
    Nested#(C) nested;
    ArrayDefault#(C) array_default;
    array_default=new;
    array_default.items[1]=new;
    if(array_default.items[1]==null) $fatal(1,"array default elaboration");
    nested=new;
    if(nested.box==null || nested.box.item==null)
      $fatal(1,"nested dependent default elaboration");
    omitted=new;
    omitted.value=37;
    base=omitted;
    if(!$cast(explicit_pair,base)) $fatal(1,"explicit default identity");
    if(!$cast(named_pair,base)) $fatal(1,"named alias identity");
    if(!$cast(defaults,base)) $fatal(1,"all defaults identity");
    if(explicit_pair!=omitted || named_pair.value!=37 || defaults.value!=37)
      $fatal(1,"cast must preserve the object");
    Pair#(A)::count=19;
    if(Pair#(A,B)::count!=19 || Pair#(.U(B))::count!=19)
      $fatal(1,"matching specialization static storage");
    if($cast(different,base) || $cast(different_second,base)
       || $cast(other_argument,base) || $cast(other_owner,base))
      $fatal(1,"different parameter or declaration owner merged");
    base=Forward#(A)::make();
    if(!$cast(explicit_pair,base)) $fatal(1,"concrete forwarding identity");
    base=Forward#(C)::make();
    if(!$cast(different,base) || $cast(explicit_pair,base))
      $fatal(1,"forwarded actual replaced by template default");
    $display("PASSED");
  end
endmodule

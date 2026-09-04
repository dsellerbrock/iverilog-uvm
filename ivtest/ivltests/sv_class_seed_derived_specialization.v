// IEEE 1800-2017/2023 8.25: "A generic class is not a type; only a concrete
// specialization represents a type."
//
// A template seed can MATERIALIZE another class's specialization from its own
// default type parameters, and that specialization is then unreachable from
// the design too. UVM does exactly this:
//
//   class uvm_in_order_class_comparator #( type T = int )
//     extends uvm_in_order_comparator #( T , ... , uvm_class_pair #( T, T ) );
//
// Elaborating that seed makes uvm_class_pair#(int,int), whose body then reads
// `T1 first; first = new;' as `int first; first = new;' and reported
//   warning: 'new' into a 4-state l-value ... degrading to null
// Likewise uvm_random_stimulus#(uvm_transaction) reported
//   warning: new of virtual class `uvm_transaction' degraded to null
//
// Nothing instantiates either. Seed-ness must PROPAGATE through
// specialization: a class materialized while a seed is being elaborated is
// part of that seed.
//
// This shape is why six reducers written as self-reference WITHIN one class
// all came back clean -- the real path crosses classes.
//
// The residual must stay LOUD: a genuine specialization that really does
// collapse is still reported, which sv_class_virt_new_fail and
// sv_class_virtual_new_in_method_fail pin.

virtual class vbase;
  pure virtual function int who();
endclass

class conc extends vbase;
  function int who(); return 7; endfunction
endclass

// Body is only meaningful when T is a class; under the `int' default it is not.
class holder #(type T = int);
  T item;
  function void make(); item = new; endfunction
  function int probe(); return (item == null) ? -1 : 1; endfunction
endclass

// Body is only meaningful when V is concrete; under the virtual default it is not.
class vholder #(type V = vbase);
  V obj;
  function void make(); obj = new; endfunction
endclass

// THE SEED. Its own default T = int materializes holder#(int) and
// vholder#(vbase) purely by naming them, and neither is ever instantiated.
class seed_owner #(type T = int);
  typedef holder #(T)  pair_t;
  typedef vholder #(T) vpair_t;
  pair_t  p;
  vpair_t v;
endclass

// A REAL specialization, which must keep working.
class user;
  holder #(conc) h;
  function new(); h = new(); endfunction
endclass

module main;

  user u;
  int errors = 0;

  initial begin
    u = new();
    u.h.make();
    if (u.h.probe() != 1) begin
      $display("FAILED: real specialization produced null");
      errors += 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule

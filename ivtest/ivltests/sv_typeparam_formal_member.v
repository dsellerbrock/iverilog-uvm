// P1 backlog item: member access on output/ref formals typed by type
// parameters. The original defect ("Variable t does not have a field
// named ...", m7 stress findings 2026-07-18) fired when a method
// dereferenced an output formal whose type is a class type parameter.
// Intervening M1B typing and virtual-output copy-back fixes resolved it;
// this test pins every shape probed during closure so it cannot silently
// regress:
//   1. output-T deref (write) inside a parameterized class method.
//   2. ref-T deref (read-modify-write) in a parameterized class method.
//   3. output-T deref in an override inheriting T from a specialized base.
//   4. output-T produced by a nested parameterized call, deref'd after.
//   5. virtual dispatch through a parameterized BASE handle; the override
//      derefs subclass-only members of its output formal.
//   6. nested member deref through the formal (t.sub.inner) in an output
//      task and a ref function.

module sv_typeparam_formal_member;

  int errors = 0;

  class Sub; int inner = 0; endclass

  class Item;
    int val = 0;
    string name = "none";
    Sub sub;
    function new(); sub = new; endfunction
  endclass

  class Special extends Item;
    int extra = 0;
  endclass

  // Shapes 1, 2, 6.
  class Box #(type T = Item);
    task fill(output T out);
      out = new;
      out.val = 42;              // 1: member write on output-T formal
      out.name = "filled";
    endtask
    task bump(ref T obj);
      obj.val++;                 // 2: member rmw on ref-T formal
    endtask
    task deepset(output T t);
      t = new;
      t.sub.inner = 9;           // 6: nested member store through output T
      t.val = 4;
    endtask
    function int probe(ref T t);
      return t.val + t.sub.inner; // 6: nested member read through ref T
    endfunction
  endclass

  // Shape 3.
  virtual class AbsGetter #(type T = Item);
    pure virtual task get(output T t);
  endclass
  class ItemGetter extends AbsGetter #(Item);
    task get(output T t);
      t = new;
      t.val = 7;                 // T inherited from the specialized base
    endtask
  endclass

  // Shapes 4 and 5.
  class Getter #(type T = Item);
    virtual task get(output T t);
      t = new;
      t.val = 1;
    endtask
  endclass
  class SpecialGetter extends Getter #(Special);
    task get(output Special t);
      t = new;
      t.val = 2;
      t.extra = 3;               // subclass member on the output formal
    endtask
  endclass
  class Agent #(type G = Getter#(Item));
    G g = new;
    task run(output Item t);
      g.get(t);
      t.val += 1;                // 4: deref after nested parameterized call
    endtask
  endclass

  task automatic expect_int(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %0d exp %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    Box #(Item) b = new;
    ItemGetter ig = new;
    Getter #(Special) basep;
    SpecialGetter sg = new;
    Agent #(Getter#(Item)) ag = new;
    Item it, it2, it3;
    Special s;

    b.fill(it);
    if (it == null) begin $display("FAIL fill null"); errors++; end
    else begin
      expect_int("fill val", it.val, 42);
      if (it.name != "filled") begin $display("FAIL fill name"); errors++; end
      b.bump(it);
      expect_int("bump val", it.val, 43);
    end

    ig.get(it2);
    if (it2 == null) begin $display("FAIL getter null"); errors++; end
    else expect_int("inherited-T val", it2.val, 7);

    basep = sg;
    basep.get(s);
    if (s == null) begin $display("FAIL vdispatch null"); errors++; end
    else begin
      expect_int("vdispatch val", s.val, 2);
      expect_int("vdispatch extra", s.extra, 3);
    end

    ag.run(it3);
    if (it3 == null) begin $display("FAIL agent null"); errors++; end
    else expect_int("agent val", it3.val, 2);

    b.deepset(it);
    expect_int("deep inner", it.sub.inner, 9);
    expect_int("probe sum", b.probe(it), 13);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule

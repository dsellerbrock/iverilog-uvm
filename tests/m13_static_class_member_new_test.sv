// IEEE 1800-2017 8.9: a static class property may be referenced through
// an object handle. An unqualified new is contextualized by the complete
// property l-value type.

class m13_named_item;
  string name;
  static string last_name;

  function new(string name);
    this.name = name;
    last_name = name;
  endfunction
endclass

class m13_static_owner #(type T = int);
  static m13_static_owner #(T) inst;
  static m13_named_item item;

  static function m13_static_owner #(T) initialize();
    if (inst == null) begin
      inst = new;
      inst.item = new("member");
    end
    return inst;
  endfunction
endclass

module m13_static_class_member_new_test;
  initial begin
    m13_static_owner #(int) owner;
    owner = m13_static_owner #(int)::initialize();

    if (owner == null) begin
      $display("FAIL: owner was overwritten by member construction");
      $finish(1);
    end
    if (m13_static_owner #(int)::item == null) begin
      $display("FAIL: static member was not constructed");
      $finish(1);
    end
    if (m13_named_item::last_name != "member") begin
      $display("FAIL: wrong member constructor argument: %s",
               m13_named_item::last_name);
      $finish(1);
    end

    $display("PASS");
  end
endmodule

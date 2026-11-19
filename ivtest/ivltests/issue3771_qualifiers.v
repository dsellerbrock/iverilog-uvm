package origins;
  class Imported;
    static int boxed;
    static task set(int n);
      boxed = n;
    endtask
    static function int get();
      return boxed;
    endfunction
  endclass
endpackage
import origins::Imported;
typedef Imported Alias;
class UnitClass;
  static int state = 29;
endclass
package uses;
  function int via_alias();
    return Alias::get();
  endfunction
  task run();
    Alias::set(17);
    UnitClass::state = 31;
  endtask
  function int via_class();
    return UnitClass::state;
  endfunction
endpackage
module top;
  initial begin
    uses::run();
    if (uses::via_alias() !== 17 || uses::via_class() !== 31)
      $fatal(1, "wrong result");
    $display("PASSED");
  end
endmodule

// IEEE1800-2017/2023: size() and $countones return signed int.
class typed_builtin;
  rand bit [7:0] mask;
  rand bit values[];
  constraint c {
    mask == 1;
    values.size() == 1;
    int'(($countones(mask) << 31) / 2) == -1073741824;
    int'((values.size() << 31) / 2) == -1073741824;
  }
endclass
module main;
  typed_builtin item = new;
  initial begin
    if (!item.randomize()) $fatal(1,"signed builtin result lost in cast");
    if (item.mask != 1 || item.values.size() != 1) $fatal(1,"wrong solved operands");
    $display("PASSED");
  end
endmodule

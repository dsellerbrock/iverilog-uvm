// IEEE 1800-2023 8.30: weak_reference#(T) named through `import std::*;`.
// The compiler used to hang (a wildcard-import cycle while resolving the
// type) and then lose the std class after the file.
import std::*;
class C; int value; endclass
module top;
  C object;
  weak_reference#(C) weak_object;
  initial begin
    object = new;
    weak_object = new(object);
    if (weak_object.get() != object) $fatal(1, "weak get");
    weak_object.clear();
    if (weak_object.get() != null) $fatal(1, "weak clear");
    if (weak_reference#(C)::get_id(object) == 0) $fatal(1, "weak id");
    $display("PASSED");
  end
endmodule

// $cast between two different specializations of the same parameterized
// class must be rejected at run time. The run-time type check compared
// class handles by their bare class name (vpiName), which is identical
// ("Box") for every specialization, so a cast from Box#(shortint) to a
// Box#(byte) handle wrongly succeeded. The check now uses the class
// dispatch prefix (exposed via vpiDefName), which is distinct per
// specialization, so Box#(byte) and Box#(shortint) no longer alias.
// A cast to the correct specialization, and ordinary inheritance
// up/down casts, are unaffected.
module sv_cast_param_class_specialization;
  class Obj;
  endclass
  class Box #(type T = int) extends Obj;
    T val;
  endclass

  Obj o;
  Box#(byte)     wrong;
  Box#(shortint) right;
  int errors = 0;

  initial begin
    Box#(shortint) src = new;
    o = src;                      // upcast to the common base Obj

    // Same specialization: must succeed.
    if (!$cast(right, o)) begin
      $display("FAIL: cast to matching specialization rejected");
      errors++;
    end

    // Different specialization of the same parameterized class: must fail.
    if ($cast(wrong, o)) begin
      $display("FAIL: cast to Box#(byte) from Box#(shortint) wrongly succeeded");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule

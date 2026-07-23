// Silent-miscompile hunt: $cast to an ENUM destination must check membership
// (IEEE 1800-2017 6.19.4, 8.16). Formerly any integral value "cast" to an
// enum reported success and stored the invalid value. Elaboration now passes
// the enum typespec as a hidden argument (the enum-method pattern) and the
// $cast implementation validates the source against the member list: on
// mismatch it returns 0 and leaves the destination unmodified. Also locks in
// class up/down-cast success and failure, and dispatch after $cast.
module sv_cast_enum_check;
  typedef enum logic [1:0] { RED=1, GREEN=2, BLUE=3 } col_t;
  class Base; virtual function int f(); return 1; endfunction endclass
  class Der extends Base; virtual function int f(); return 2; endfunction endclass
  int errors = 0;
  initial begin
    automatic col_t y = GREEN;
    automatic int ok;

    ok = $cast(y, 3);
    if (!ok || y !== BLUE) begin $display("FAIL valid cast"); errors++; end
    ok = $cast(y, 0);            // 0 is not a member
    if (ok) begin $display("FAIL invalid cast succeeded"); errors++; end
    if (y !== BLUE) begin $display("FAIL dest modified=%0d", y); errors++; end
    ok = $cast(y, 1);
    if (!ok || y !== RED) begin $display("FAIL re-valid"); errors++; end

    begin
      automatic Base b;
      automatic Der d0 = new;
      automatic Der d;
      b = d0;
      if (!$cast(d, b) || d.f() !== 2) begin $display("FAIL class downcast"); errors++; end
      b = new;
      if ($cast(d, b)) begin $display("FAIL bad downcast succeeded"); errors++; end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule

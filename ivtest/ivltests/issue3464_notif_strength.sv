module issue3464_notif_strength;
  reg d, c;
  wire n0, n1, b0, b1, weak_n0, pulled_up, pulled_down;
  integer errors = 0;

  notif0 (n0, d, c);
  notif1 (n1, d, c);
  bufif0 (b0, ~d, c);
  bufif1 (b1, ~d, c);
  notif0 (weak0, weak1) (weak_n0, d, c);
  notif0 (pulled_up, d, c);
  pullup (pulled_up);
  notif1 (pulled_down, d, c);
  pulldown (pulled_down);

  task check;
    input data, control;
    input [23:0] expected0, expected1, expected_weak;
    begin
      d = data; c = control; #1;
      if ($sformatf("%v", n0) != expected0 ||
          $sformatf("%v", n1) != expected1 ||
          $sformatf("%v", b0) != expected0 ||
          $sformatf("%v", b1) != expected1 ||
          $sformatf("%v", weak_n0) != expected_weak) begin
        $display("FAIL d=%b c=%b: %v %v %v %v %v expected %s %s %s",
                 d, c, n0, n1, b0, b1, weak_n0,
                 expected0, expected1, expected_weak);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    check(0, 0, "St1", "HiZ", "We1");
    check(0, 1, "HiZ", "St1", "HiZ");
    check(0, 1'bx, "StH", "StH", "WeH");
    if ($sformatf("%v %b %v %b", pulled_up, pulled_up, pulled_down, pulled_down) != "651 1 56X x") begin
      $display("FAIL resolved H: %v %b %v %b", pulled_up, pulled_up, pulled_down, pulled_down);
      errors = errors + 1;
    end
    check(0, 1'bz, "StH", "StH", "WeH");
    check(1, 0, "St0", "HiZ", "We0");
    check(1, 1, "HiZ", "St0", "HiZ");
    check(1, 1'bx, "StL", "StL", "WeL");
    if ($sformatf("%v %b %v %b", pulled_up, pulled_up, pulled_down, pulled_down) != "65X x 650 0") begin
      $display("FAIL resolved L: %v %b %v %b", pulled_up, pulled_up, pulled_down, pulled_down);
      errors = errors + 1;
    end
    check(1, 1'bz, "StL", "StL", "WeL");
    check(1'bx, 0, "StX", "HiZ", "WeX");
    check(1'bx, 1, "HiZ", "StX", "HiZ");
    check(1'bx, 1'bx, "StX", "StX", "WeX");
    check(1'bx, 1'bz, "StX", "StX", "WeX");
    check(1'bz, 0, "StX", "HiZ", "WeX");
    check(1'bz, 1, "HiZ", "StX", "HiZ");
    check(1'bz, 1'bx, "StX", "StX", "WeX");
    check(1'bz, 1'bz, "StX", "StX", "WeX");
    if (!errors) $display("PASS");
    else $display("FAIL: %0d errors", errors);
  end
endmodule

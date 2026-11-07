// IEEE 1800-2023 6.16 / 5.9: string literals (also through an
// untyped parameter), string-typed expressions, explicit string casts and
// string concatenations remain directly assignable to a string.
module issue733_string_cast_legal;
  typedef string str_t;
  typedef enum {RED, GREEN} col_t;
  parameter UP = "lit";
  localparam LP = {"x", "y"};
  parameter string TP = "typed";
  string s, t;
  logic [15:0] v = 16'h4142;
  byte b = 8'h43;
  bit c = 1;
  col_t col = GREEN;
  string q[$] = '{"q0", "q1"};
  byte bq[$] = '{8'h44, 8'h45};
  bit fail = 0;
  function string pass_through(input string x = "dflt"); return x; endfunction
  task check(input string got, input string exp);
    if (got != exp) begin
      $display("FAILED: got '%s' expected '%s'", got, exp);
      fail = 1;
    end
  endtask
  initial begin
    s = "abc";            check(s, "abc");
    s = UP;               check(s, "lit");
    s = LP;               check(s, "xy");
    s = TP;               check(s, "typed");
    s = string'(v);       check(s, "AB");
    s = str_t'(b);        check(s, "C");
    s = {"<", string'(v), ">"}; check(s, "<AB>");
    s = c ? "yes" : "no"; check(s, "yes");
    s = $sformatf("%0d", v); check(s, "16706");
    s = col.name();       check(s, "GREEN");
    s = q.pop_front();    check(s, "q0");
    s = {>>{bq}};         check(s, "DE");
    t = pass_through();   check(t, "dflt");
    t = pass_through(s);  check(t, "DE");
    if (!fail) $display("PASSED");
  end
endmodule

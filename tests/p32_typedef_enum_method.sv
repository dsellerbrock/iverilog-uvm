// G31: chained enum.method() on function-return value
typedef enum {RED=0, GREEN=1, BLUE=2} color_t;

function automatic color_t get_color();
  return GREEN;
endfunction

module p32_typedef_enum_method;
  initial begin
    string s;
    s = get_color().name();
    if (s == "GREEN")
      $display("PASS");
    else
      $display("FAIL: got %s", s);
  end
endmodule

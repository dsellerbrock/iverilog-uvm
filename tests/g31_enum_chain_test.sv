// G31: enum method on function-return value (e.g., get_e().name())
module g31_enum_chain_test;
  typedef enum logic [1:0] { RED=0, GREEN=1, BLUE=2 } color_t;

  function automatic color_t get_color(input int idx);
    case (idx)
      0: return RED;
      1: return GREEN;
      default: return BLUE;
    endcase
  endfunction

  initial begin
    string s;
    s = get_color(0).name();
    if (s != "RED") begin $display("FAIL: got %s", s); $finish; end
    s = get_color(1).name();
    if (s != "GREEN") begin $display("FAIL: got %s", s); $finish; end
    s = get_color(2).name();
    if (s != "BLUE") begin $display("FAIL: got %s", s); $finish; end
    $display("PASS");
  end
endmodule

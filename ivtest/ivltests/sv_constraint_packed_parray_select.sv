// A packed array of packed structs selects an entire element; symbolic
// nested selection remains explicitly unsupported until it is modeled.
typedef struct packed { logic [1:0] v; } word_t;
typedef struct packed { word_t [1:0] words; } holder_t;
class constant_element;
  rand holder_t h;
  constraint k { h.words[1] == 2'b10; h.words[0] == 2'b01; }
endclass
class symbolic_element;
  rand holder_t h;
  rand bit [1:0] idx;
  constraint k { idx == 2; h.words[idx] == 2'b00; }
endclass
module test;
  initial begin
    constant_element c;
    symbolic_element s;
    c = new; s = new;
    if (!c.randomize() || c.h.words[1] != 2'b10
        || c.h.words[0] != 2'b01)
      $fatal(1, "constant packed-array element was not exact");
    if (s.randomize())
      $fatal(1, "symbolic nested packed select silently succeeded");
    $display("PASSED");
  end
endmodule

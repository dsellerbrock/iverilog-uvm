// IEEE 1800-2017 18.12: a class variable passed to std::randomize denotes
// the live object's random state; an inline constraint may retain the
// lexical handle prefix and select a packed-struct member.
module std_randomize_class_handle_test;
  typedef struct packed {
    bit [6:0] payload;
    bit       valid;
  } key_t;

  class request;
    rand key_t key;
  endclass

  initial begin
    request req = new;
    repeat (8) begin
      req.key = '0;
      if (!std::randomize(req) with { req.key.valid == 1; }) begin
        $display("FAIL: class-handle std::randomize returned false");
        $finish;
      end
      if (req.key.valid !== 1'b1) begin
        $display("FAIL: rooted inline constraint was not enforced");
        $finish;
      end
    end
    $display("PASS: class-handle std::randomize rooted constraint");
    $finish;
  end
endmodule

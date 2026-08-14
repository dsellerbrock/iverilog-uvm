module test;
  int x;
  int y;
  int ok;

  initial begin
    ok = std::randomize(x) with (y) { x == y; };
    std::randomize(x) with () { x == 1; };
    ok = randomize(x) with (y) { x == y; };
    void'(std::randomize(x) with (y) { x == y; });
    void'(std::randomize(x) with () { x == 1; });
    ok = std::randomize(x) with (y) { };
    void'(std::randomize(x) with () { });
  end
endmodule

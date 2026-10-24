// IEEE 1800-2017 §18.11 / IEEE 1800-2023 §18.11: only property names are allowed.
class CA;
  rand byte x;
endclass

module test;
  initial begin
    CA a = new;
    void'(a.randomize(x + 1));
  end
endmodule

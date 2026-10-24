// IEEE 1800-2017 §18.11 / IEEE 1800-2023 §18.11: local members are inaccessible here.
class CA;
  local rand byte x;
endclass

module test;
  initial begin
    CA a = new;
    void'(a.randomize(x));
  end
endmodule

// IEEE 1800-2017/2023 12.8 forbids a fork child from controlling an
// enclosing loop.
module test;
  initial begin
    for (int i = 0; i < 1; i++) begin
      fork begin break; end join
    end

    for (int i = 0; i < 2; i++) fork continue; join
  end
endmodule

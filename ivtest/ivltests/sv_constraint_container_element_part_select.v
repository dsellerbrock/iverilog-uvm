// A packed part or bit select of one element of a non-random queue,
// dynamic array or fixed array is an ordinary constraint operand (IEEE
// 1800-2017/2023 11.5.1, 18.5). It was reported as "not representable in the
// constraint solver", so randomize() of the class failed (OpenTitan spi_device).
class k;
  rand bit [7:0] d[$];
  rand bit [7:0] e, f, h;
  rand bit g;
  int src[$];
  int dyn[];
  int arr[4];
  constraint a { d.size() == 3; foreach (d[i]) d[i] == src[i][7:0]; }
  constraint b { e == src[1][15:8]; }
  constraint c { f == arr[2][7:0]; }
  constraint d2 { h == dyn[1][3:0]; g == dyn[0][2]; }
endclass

module main;
  int errors;
  initial begin
    k c;
    c = new;
    c.src = '{32'h11, 32'h2233, 32'h44};
    c.dyn = new[2];
    c.dyn[0] = 4; c.dyn[1] = 32'h5a;
    c.arr = '{1, 2, 32'h1ff, 4};
    repeat (3) begin
      if (!c.randomize()) begin $display("FAILED randomize"); errors++; end
      else begin
        if (c.d.size() != 3 || c.d[0] !== 8'h11 || c.d[1] !== 8'h33 || c.d[2] !== 8'h44) begin
          $display("FAILED d %p", c.d); errors++;
        end
        if (c.e !== 8'h22) begin $display("FAILED e %h", c.e); errors++; end
        if (c.f !== 8'hff) begin $display("FAILED f %h", c.f); errors++; end
        if (c.h !== 8'h0a) begin $display("FAILED h %h", c.h); errors++; end
        if (c.g !== 1'b1) begin $display("FAILED g %b", c.g); errors++; end
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule

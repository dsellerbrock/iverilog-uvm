// G14/G42: typed-default in assignment pattern '{int: 0, default: 8'hFF}
// Tests both the simple default: form and the typed-key form
module g14_typed_default_test;
  typedef struct packed {
    byte a;
    byte b;
  } my_s;

  my_s s1, s2;

  initial begin
    // Test 1: simple default form (G13 fix applies here too)
    s1 = '{default: 8'hFF};
    if (s1.a === 8'hFF && s1.b === 8'hFF) begin
      $display("PASS s1: a=%0h b=%0h", s1.a, s1.b);
    end else begin
      $display("FAIL s1: a=%0h b=%0h (expected FF FF)", s1.a, s1.b);
      $finish(1);
    end

    // Test 2: explicit member defaults (basic named pattern)
    s2 = '{a: 8'hAA, b: 8'hBB};
    if (s2.a === 8'hAA && s2.b === 8'hBB) begin
      $display("PASS s2: a=%0h b=%0h", s2.a, s2.b);
    end else begin
      $display("FAIL s2: a=%0h b=%0h (expected AA BB)", s2.a, s2.b);
      $finish(1);
    end
  end
endmodule

// IEEE 1800-2017 §18.5.5; IEEE 1800-2023 §18.5.4.
class S1;
  rand byte a[5]; rand byte b; rand byte e;
  constraint c { unique {a[2:3]}; }
endclass
class S2;
  rand byte a[5]; rand byte b; rand byte e;
  constraint c { unique {b, e}; }
endclass
class S3;
  rand byte a[5]; rand byte b; rand byte e;
  constraint c { unique {b, a}; }
endclass
class S4;
  rand byte a[5]; rand byte b; rand byte e;
  constraint c { unique {b, a[2:3]}; }
endclass
class S5;
  rand byte a[5]; rand byte b; rand byte e;
  constraint c { unique {b, a[2:3], e}; }
endclass
class S6;
  rand byte a[5]; rand byte b; rand byte e;
  constraint c { unique {a[1], a[3]}; }
endclass

module p18_05_5_unique_shapes;
  initial begin
    S1 s1; S2 s2; S3 s3; S4 s4; S5 s5; S6 s6;
    int ok1, bad1, ok2, bad2, ok3, bad3, ok4, bad4, ok5, bad5, ok6, bad6;
    int i, j;

    s1 = new; s2 = new; s3 = new; s4 = new; s5 = new; s6 = new;
    ok1 = 0; bad1 = 0; ok2 = 0; bad2 = 0; ok3 = 0; bad3 = 0;
    ok4 = 0; bad4 = 0; ok5 = 0; bad5 = 0; ok6 = 0; bad6 = 0;

    repeat (50) begin
      if (s1.randomize()) begin ok1++; if (s1.a[2] == s1.a[3]) bad1++; end
      if (s2.randomize()) begin ok2++; if (s2.b == s2.e) bad2++; end
      if (s3.randomize()) begin
        ok3++;
        for (i = 0; i < 5; i++) begin
          if (s3.b == s3.a[i]) bad3++;
          for (j = i + 1; j < 5; j++) if (s3.a[i] == s3.a[j]) bad3++;
        end
      end
      if (s4.randomize()) begin
        ok4++;
        if (s4.b == s4.a[2] || s4.b == s4.a[3] || s4.a[2] == s4.a[3]) bad4++;
      end
      if (s5.randomize()) begin
        ok5++;
        if (s5.b == s5.a[2] || s5.b == s5.a[3] || s5.b == s5.e ||
            s5.a[2] == s5.a[3] || s5.a[2] == s5.e || s5.a[3] == s5.e) bad5++;
      end
      if (s6.randomize()) begin ok6++; if (s6.a[1] == s6.a[3]) bad6++; end
    end

    $display("S1 ok=%0d bad=%0d", ok1, bad1);
    $display("S2 ok=%0d bad=%0d", ok2, bad2);
    $display("S3 ok=%0d bad=%0d", ok3, bad3);
    $display("S4 ok=%0d bad=%0d", ok4, bad4);
    $display("S5 ok=%0d bad=%0d", ok5, bad5);
    $display("S6 ok=%0d bad=%0d", ok6, bad6);
  end
endmodule

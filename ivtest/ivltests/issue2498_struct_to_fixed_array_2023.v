module issue2498_struct_to_fixed_array;
  typedef byte unsigned b4_t[4];
  typedef struct { shortint unsigned a; byte unsigned c[2]; } s_t;

  b4_t ba;
  s_t s;

  initial begin
    s.a = 16'h1122;
    s.c[0] = 8'h33;
    s.c[1] = 8'h44;
    ba = b4_t'(s);

    if (ba[0] !== 8'h11 || ba[1] !== 8'h22
        || ba[2] !== 8'h33 || ba[3] !== 8'h44)
      $fatal(1, "struct-to-array order: %02h %02h %02h %02h",
             ba[0], ba[1], ba[2], ba[3]);
    $display("PASS issue2498 struct-to-fixed-array bit-stream cast");
  end
endmodule

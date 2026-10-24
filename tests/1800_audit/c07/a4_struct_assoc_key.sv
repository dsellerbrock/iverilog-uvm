typedef struct { byte B; int I; } U;
module a4_struct_assoc_key;
  int au[U];
  U u1, u2, u3;
  initial begin
    $display("BEGIN a4"); $fflush;
    u1 = '{1, 10}; u2 = '{2, 20}; u3 = '{1, 11};
    au[u1] = 5; au[u2] = 6;
    $display("A4 %0d %0d %0d", au.size(), au[u1], au.exists(u3));
  end
endmodule

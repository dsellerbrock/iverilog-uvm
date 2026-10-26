module sv_randsequence_join_nested_lanes;
  int order;
  initial begin
    randsequence (TOP)
      TOP : rand join S1 S2;
      S1 : A B;
      S2 : C D;
      A : { order = order * 10 + 1; };
      B : { order = order * 10 + 2; };
      C : { order = order * 10 + 3; };
      D : { order = order * 10 + 4; };
    endsequence
    if (!(order inside {1234,1324,1342,3124,3142,3412}))
      $fatal(1, "order=%0d", order);
    $display("PASS");
  end
endmodule

module m12_decl_lifetime_words;
  task static explicit_automatic;
    automatic int da[];
    automatic int q[$];
    da = new[1];
    da[0] = 11;
    q.push_back(12);
    $check_word_lifetime(1, da, q);
  endtask

  task automatic explicit_static;
    static int da[];
    static int q[$];
    da = new[1];
    da[0] = 21;
    q.delete();
    q.push_back(22);
    $check_word_lifetime(0, da, q);
  endtask

  initial begin
    explicit_automatic();
    explicit_static();
    $display("PASSED");
    $finish(0);
  end
endmodule

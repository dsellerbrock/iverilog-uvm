module sv_assoc_first_void_cast;
  int aa[int];
  int k;

  initial begin
    aa[8] = 1;
    void'(aa.first(k));
    if (k !== 8)
      $fatal(1, "void-cast first() did not assign the associative key");

    begin : local_scope
      int local_key;
      void'(aa.first(local_key));
      if (local_key !== 8)
        $fatal(1, "void-cast first() did not assign a block-local key");
    end

    $display("ASSOC_FIRST_VOID_CAST_PASS");
  end
endmodule

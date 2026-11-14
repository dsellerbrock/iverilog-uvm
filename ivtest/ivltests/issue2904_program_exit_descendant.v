program issue2904_program_exit_descendant_program;
  initial begin
    fork
      begin
        #5 $exit();
        $display("FAIL: exit descendant continued");
      end
    join_none
    #20 $display("FAIL: originating initial continued");
  end

  initial begin
    #15 $display("FAIL: peer initial continued");
  end
endprogram

module issue2904_program_exit_descendant;
  issue2904_program_exit_descendant_program p();

  initial begin
    #2 $exit();
    $display("MODULE $exit ignored");
    #10 $display("FAIL: module process continued");
  end

  final $display("FINAL t=%0t", $time);
endmodule

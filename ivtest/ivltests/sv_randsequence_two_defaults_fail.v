module sv_randsequence_two_defaults_fail;
  initial begin
    randsequence ()
      select : case (1)
        0       : choice;
        default : choice;
        default : choice;
      endcase;
      choice : { };
    endsequence
  end
endmodule

module sv_chandle_compound_assignment_incompatible_fail;
  chandle ch;
  int value;

  initial value += ch;
endmodule

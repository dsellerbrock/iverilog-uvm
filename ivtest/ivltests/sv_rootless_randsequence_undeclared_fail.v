function int choose_value();
  int value;
  randsequence (main)
    main : production;
    production : { if (missing_switch) value = 1; else value = 0; };
  endsequence
  return value;
endfunction

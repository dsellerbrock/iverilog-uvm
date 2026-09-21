class C;
  string names[3];

  function new();
    int p;
    p = 0;
    foreach (names[i]) begin
      p::wakeup_e wakeup;
      wakeup = p::wakeup_e'(i);
      names[i] = {wakeup.name(), "_cg"};
      p = p + 1;
    end
  endfunction

  function string boundary_name();
    p::wakeup_e wakeup;
    wakeup = p::wakeup_e'(3);
    return wakeup.name();
  endfunction
endclass

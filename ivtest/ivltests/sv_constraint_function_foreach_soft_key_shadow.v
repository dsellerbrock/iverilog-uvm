class soft_key_plain;
  bit cyc;
endclass
class soft_key_shadow;
  randc bit cyc;
endclass
class soft_key_value;
  bit dummy;
endclass
class soft_key_holder;
  soft_key_value entries[soft_key_plain];
  soft_key_shadow i; // Must lose to the typed foreach key iterator.
  rand int result;
  bit fail;
  constraint c {
    foreach(entries[i]) soft (i.cyc == 0);
    result == 7;
    fail -> result == 8;
  }
  function new; i=new; endfunction
endclass
module test;
  soft_key_holder h; soft_key_plain key; soft_key_value value; int ok;
  initial begin
    h=new; key=new; value=new; key.cyc=1; h.i.cyc=1;
    h.entries[key]=value;
    ok=h.randomize();
    if(!ok || h.result!=7 || key.cyc!=1 || h.i.cyc!=1)
      $fatal(1,"assoc soft key iterator shadow");
    h.fail=1; ok=h.randomize();
    if(ok || h.result!=7 || key.cyc!=1 || h.i.cyc!=1)
      $fatal(1,"assoc soft key rollback");
    $display("PASSED");
  end
endmodule

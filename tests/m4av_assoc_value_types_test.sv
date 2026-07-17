// M4-av: module-static associative arrays with STRING and REAL element
// values (IEEE 1800-2017 7.8). M14 fixed integer(vec4)-valued int-keyed
// reads; string- and real-VALUED assoc reads still silently returned the
// empty string / 0.0 for a bare-signal (module-static) container, for
// both integer and string keys (the store used %aa/store but the read
// used a positional %load/dar/*). Class-member assoc reads (via
// %prop/obj) were unaffected. Now the bare-signal read emits the keyed
// %aa/load/{str,r}/{v,str} form.
module m4av_assoc_value_types_test_top;
  string si[int];       // int key,   string value
  string ss[string];    // string key, string value
  real   ri[int];       // int key,   real value
  real   rs[string];    // string key, real value

  string sq[$];         // string queue (positional) — must stay correct
  real   rq[$];         // real queue (positional)

  int errors = 0;
  task cks(string w, string g, string e);
    if (g != e) begin $display("FAIL: %s got='%s' exp='%s'", w, g, e); errors++; end
  endtask
  task ckr(string w, real g, real e);
    if (g != e) begin $display("FAIL: %s got=%0.3f exp=%0.3f", w, g, e); errors++; end
  endtask

  initial begin
    si[5] = "hello"; si[10] = "world";
    ss["a"] = "alpha"; ss["b"] = "beta";
    ri[3] = 2.5; ri[7] = -1.25;
    rs["x"] = 3.14; rs["y"] = 0.5;
    sq.push_back("q0"); sq.push_back("q1");
    rq.push_back(9.5);  rq.push_back(8.25);

    cks("si[5]",  si[5],  "hello");
    cks("si[10]", si[10], "world");
    cks("ss[a]",  ss["a"], "alpha");
    cks("ss[b]",  ss["b"], "beta");
    ckr("ri[3]",  ri[3],  2.5);
    ckr("ri[7]",  ri[7],  -1.25);
    ckr("rs[x]",  rs["x"], 3.14);
    ckr("rs[y]",  rs["y"], 0.5);

    // positional queues unaffected
    cks("sq[0]", sq[0], "q0");
    cks("sq[1]", sq[1], "q1");
    ckr("rq[0]", rq[0], 9.5);
    ckr("rq[1]", rq[1], 8.25);

    // update, foreach, exists/num/delete, missing-key default
    si[5] = "updated"; cks("si[5] updated", si[5], "updated");
    begin
      string acc = "";
      foreach (ss[k]) acc = {acc, ss[k]};
      if (acc != "alphabeta" && acc != "betaalpha") begin
        $display("FAIL: foreach ss acc='%s'", acc); errors++;
      end
    end
    if (!si.exists(10)) begin $display("FAIL: si.exists"); errors++; end
    si.delete(10);
    if (si.exists(10)) begin $display("FAIL: si post-delete"); errors++; end
    cks("missing key default", si[999], "");
    ckr("missing real default", ri[999], 0.0);

    if (errors == 0) $display("PASS: m4av assoc value types");
    else $display("FAIL: m4av assoc value types (%0d errors)", errors);
    $finish(0);
  end
endmodule

// R16: $cast destinations that are SELECTs over local or nested containers
// use the same element stores as ordinary assignment. Failed casts leave
// every destination unchanged.
module main;
  class Base;
    int id;
  endclass
  class Der extends Base;
  endclass
  class Inner;
    Der q[$];
    Der am[string];
  endclass
  class Outer;
    Inner inn;
  endclass

  Der fixed[3];
  Der dyn[];
  Der queue[$];
  Der assoc[string];
  Outer outer;
  Base good;
  Base bad;
  Der derived;
  Der keep;
  int idx = 1;
  string key = "new";
  int ok;
  int fails;

  task check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED -- %s: got=%0d want=%0d", what, got, want);
      fails++;
    end
  endtask

  function int idof(Der value);
    return value == null ? -1 : value.id;
  endfunction

  initial begin
    derived = new; derived.id = 17; good = derived;
    bad = new;
    keep = new; keep.id = 99;
    dyn = new[3];
    queue.push_back(null); queue.push_back(null);
    assoc["keep"] = derived;
    outer = new; outer.inn = new;
    outer.inn.q.push_back(null); outer.inn.q.push_back(null);
    outer.inn.am["keep"] = derived;

    ok = $cast(fixed[1], good);
    check("fixed constant result", ok, 1);
    check("fixed constant value", idof(fixed[1]), 17);
    fixed[1] = null;
    ok = $cast(fixed[idx], good);
    check("fixed variable result", ok, 1);
    check("fixed variable value", idof(fixed[idx]), 17);

    ok = $cast(dyn[idx], good);
    check("dynamic result", ok, 1);
    check("dynamic value", idof(dyn[idx]), 17);
    ok = $cast(queue[idx], good);
    check("queue result", ok, 1);
    check("queue size", queue.size(), 2);
    check("queue value", idof(queue[idx]), 17);

    ok = $cast(assoc[key], good);
    check("assoc result", ok, 1);
    check("assoc size", assoc.num(), 2);
    check("assoc value", idof(assoc[key]), 17);

    ok = $cast(outer.inn.q[idx], good);
    check("nested queue result", ok, 1);
    check("nested queue size", outer.inn.q.size(), 2);
    check("nested queue value", idof(outer.inn.q[idx]), 17);
    ok = $cast(outer.inn.am[key], good);
    check("nested assoc result", ok, 1);
    check("nested assoc size", outer.inn.am.num(), 2);
    check("nested assoc value", idof(outer.inn.am[key]), 17);

    fixed[0] = keep;
    dyn[0] = keep;
    queue[0] = keep;
    assoc["bad"] = keep;
    outer.inn.q[0] = keep;
    outer.inn.am["bad"] = keep;
    ok = $cast(fixed[0], bad);
    check("failed fixed result", ok, 0);
    check("failed fixed preserves", idof(fixed[0]), 99);
    ok = $cast(dyn[0], bad);
    check("failed dynamic result", ok, 0);
    check("failed dynamic preserves", idof(dyn[0]), 99);
    ok = $cast(queue[0], bad);
    check("failed queue result", ok, 0);
    check("failed queue preserves", idof(queue[0]), 99);
    ok = $cast(assoc["bad"], bad);
    check("failed assoc result", ok, 0);
    check("failed assoc preserves", idof(assoc["bad"]), 99);
    ok = $cast(outer.inn.q[0], bad);
    check("failed nested queue result", ok, 0);
    check("failed nested queue preserves", idof(outer.inn.q[0]), 99);
    ok = $cast(outer.inn.am["bad"], bad);
    check("failed nested assoc result", ok, 0);
    check("failed nested assoc preserves", idof(outer.inn.am["bad"]), 99);

    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule

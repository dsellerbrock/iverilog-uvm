module top;
  class Base;
    int id;
  endclass
  class Der extends Base;
  endclass
  class Inner;
    Der q[$];
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
  int idx = 1;
  int ok;
  int fails;

  task check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED %s: got=%0d want=%0d", what, got, want);
      fails++;
    end
  endtask

  initial begin
    derived = new;
    derived.id = 17;
    good = derived;
    bad = new;
    dyn = new[3];
    queue.push_back(null);
    queue.push_back(null);
    assoc["keep"] = derived;
    outer = new;
    outer.inn = new;
    outer.inn.q.push_back(null);
    outer.inn.q.push_back(null);

    ok = $cast(fixed[1], good);
    check("fixed constant result", ok, 1);
    check("fixed constant value", fixed[1].id, 17);

    ok = $cast(fixed[idx], good);
    check("fixed variable result", ok, 1);
    check("fixed variable value", fixed[idx].id, 17);

    ok = $cast(dyn[idx], good);
    check("dynamic result", ok, 1);
    check("dynamic value", dyn[idx].id, 17);

    ok = $cast(queue[idx], good);
    check("queue result", ok, 1);
    check("queue size", queue.size(), 2);
    check("queue value", queue[idx].id, 17);

    ok = $cast(assoc["new"], good);
    check("assoc result", ok, 1);
    check("assoc size", assoc.num(), 2);
    check("assoc value", assoc["new"].id, 17);

    ok = $cast(outer.inn.q[idx], good);
    check("nested queue result", ok, 1);
    check("nested queue size", outer.inn.q.size(), 2);
    check("nested queue value", outer.inn.q[idx].id, 17);

    derived = new;
    derived.id = 99;
    fixed[0] = derived;
    ok = $cast(fixed[0], bad);
    check("failed cast result", ok, 0);
    check("failed cast preserves destination", fixed[0].id, 99);

    if (fails == 0)
      $display("PASSED");
    $finish;
  end
endmodule

class target_c;
  rand int x;
  rand int z;
  int y = -1;
endclass

module test;
  target_c item;

  function automatic target_c get_item();
    return item;
  endfunction

  function automatic int constrain_from_caller(target_c obj, int y);
    return obj.randomize() with (x, z) {
      x == y - 1;
      z == x + 1;
      obj.y == -1;
    };
  endfunction

  function automatic void constrain_as_statement(target_c obj, int y);
    obj.randomize() with (x) {
      x == y - 2;
      obj.y == -1;
    };
  endfunction

  function automatic int constrain_duplicate_list(target_c obj, int y);
    return obj.randomize() with (x, x, z) {
      x == y - 2;
      z == y;
    };
  endfunction

  function automatic int constrain_empty_list(target_c obj);
    return obj.randomize() with () {
      x == 40;
      z == 41;
      y == -1;
    };
  endfunction

  initial begin
    item = new;
    if (!constrain_from_caller(item, 10))
      $fatal(1, "identifier-scoped randomize unexpectedly failed");
    if (item.x != 9 || item.z != 10 || item.y != -1)
      $fatal(1, "wrong contextual binding x=%0d z=%0d target.y=%0d",
             item.x, item.z, item.y);
    constrain_as_statement(item, 20);
    if (item.x != 18 || item.y != -1)
      $fatal(1, "wrong statement contextual binding x=%0d target.y=%0d",
             item.x, item.y);
    if (!constrain_duplicate_list(item, 30))
      $fatal(1, "duplicate identifier list unexpectedly failed");
    if (item.x != 28 || item.z != 30)
      $fatal(1, "wrong duplicate-list binding x=%0d z=%0d", item.x, item.z);
    if (!constrain_empty_list(item))
      $fatal(1, "empty identifier list unexpectedly failed");
    if (item.x != 40 || item.z != 41 || item.y != -1)
      $fatal(1, "wrong empty-list binding x=%0d z=%0d y=%0d",
             item.x, item.z, item.y);

    if (!get_item().randomize() with (x) { x == 51; })
      $fatal(1, "call-result expression randomize unexpectedly failed");
    if (item.x != 51)
      $fatal(1, "wrong call-result expression value x=%0d", item.x);

    get_item().randomize() with (z) { z == 52; };
    if (item.z != 52)
      $fatal(1, "wrong call-result statement value z=%0d", item.z);

    void'(get_item().randomize() with (x) { x == 53; });
    if (item.x != 53)
      $fatal(1, "wrong call-result void value x=%0d", item.x);

    if (!get_item().randomize() with () { x == 54; z == 55; })
      $fatal(1, "call-result empty-list randomize unexpectedly failed");
    if (item.x != 54 || item.z != 55)
      $fatal(1, "wrong call-result empty-list values x=%0d z=%0d",
             item.x, item.z);

    get_item().randomize() with () { z == 56; };
    if (item.z != 56)
      $fatal(1, "wrong call-result empty-list statement z=%0d", item.z);

    void'(get_item().randomize() with () { x == 57; });
    if (item.x != 57)
      $fatal(1, "wrong call-result empty-list void x=%0d", item.x);
    $display("PASSED");
  end
endmodule

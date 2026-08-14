module top;
  typedef union tagged packed {
    struct packed { logic [3:0] x, y; } a;
    struct packed { logic [3:0] x, y; } b;
  } value_t;

  value_t value;
  int hits;
  int result;

  initial begin
    value = tagged a '{4'd3, 4'd5};
    hits = 0;
    case (value) matches
      tagged b '{.x, .y}: $fatal(1, "wrong tag b x=%0d y=%0d", x, y);
      tagged a '{.x, 4'd4}: $fatal(1, "wrong constant matched x=%0d", x);
      tagged a '{.x, .y}: begin
        if ($bits(x) != 4 || $bits(y) != 4)
          $fatal(1, "wrong binding widths %0d/%0d", $bits(x), $bits(y));
        if (x != 3 || y != 5)
          $fatal(1, "wrong binding values %0d/%0d", x, y);
        hits++;
      end
      default: $fatal(1, "default selected");
    endcase
    if (hits != 1) $fatal(1, "case hit count %0d", hits);

    if (value matches tagged a '{4'd3, .z}) begin
      if ($bits(z) != 4 || z != 5)
        $fatal(1, "if binding width/value %0d/%0d", $bits(z), z);
      hits++;
    end else $fatal(1, "if pattern did not match");

    // The true-arm pattern variable shadows the subject name, while the
    // predicate itself must still resolve the outer tagged-union value.
    if (value matches tagged a '{.value, .*}) begin
      if ($bits(value) != 4 || value != 3)
        $fatal(1, "subject-shadow binding width/value %0d/%0d",
               $bits(value), value);
      hits++;
    end else $fatal(1, "subject-shadow pattern did not match");

    if (value matches tagged b '{.*, .*})
      $fatal(1, "wrong tag matched");

    result = value matches tagged a '{4'd3, 4'd5} ? 17 : 23;
    if (result != 17) $fatal(1, "conditional true result=%0d", result);
    result = value matches tagged a '{4'd2, .*} ? 17 : 23;
    if (result != 23) $fatal(1, "conditional false result=%0d", result);

    value = tagged a '{4'b0011, 4'b1010};
    hits = 0;
    casex (value) matches
      tagged a '{4'b00?x, .q}: begin
        if (q != 4'b1010) $fatal(1, "casex bind q=%b", q);
        hits++;
      end
      default: $fatal(1, "casex default");
    endcase
    if (hits != 1) $fatal(1, "casex hit count %0d", hits);

    value = tagged a '{4'b1101, 4'b0110};
    hits = 0;
    casez (value) matches
      tagged a '{4'b11?1, .r}: begin
        if (r != 4'b0110) $fatal(1, "casez bind r=%b", r);
        hits++;
      end
      default: $fatal(1, "casez default");
    endcase
    if (hits != 1) $fatal(1, "casez hit count %0d", hits);

    $display("PASSED");
  end
endmodule

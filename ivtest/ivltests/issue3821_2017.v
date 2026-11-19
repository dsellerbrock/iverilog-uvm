`timescale 1ns/1ns

module issue3821_strong_zero(inout wire pin);
  assign pin = 1'b0;
endmodule

module issue3821_pull_zero(inout wire pin);
  pulldown (pin);
endmodule

module issue3821_dut(inout wire count_pin, res_pin, x_pin, loop_pin, supply_pin);
  wire count_source, res_source, x_source, loop_source, via, opposing;
  supply1 clamped;
  reg count_enable = 0, enable_n = 1;
  reg supply_opposition = 1'bz;

  assign count_pin = 1'b0;
  issue3821_strong_zero counted(count_source);
  tranif1 #(2, 3) counted_path(count_pin, count_source, count_enable);

  issue3821_pull_zero resistive(res_source);
  rtran resistive_path(res_pin, res_source);

  issue3821_strong_zero uncertain(x_source);
  tranif0 uncertain_path(x_pin, x_source, enable_n);

  // The second route can change conduction without adding a driver.
  issue3821_strong_zero shared(loop_source);
  tran direct_path(loop_pin, loop_source);
  tran via_path(via, loop_source);
  rtranif0 alternate_path(loop_pin, via, enable_n);

  // Resolve at the junction before the supply-to-strong reduction.
  issue3821_strong_zero masked(opposing);
  tran opposed_path(clamped, opposing);
  tran supply_path(supply_pin, clamped);
  assign supply_pin = supply_opposition;

  initial begin
    #6 count_enable = 1; // conducts at 8
    #1 enable_n = 1'bx;
    #3 enable_n = 0;
    #1 count_enable = 0; // opens at 14
    #2 enable_n = 1;
  end

  initial begin
    #15 supply_opposition = 0;
    #2 supply_opposition = 1'bz;
  end
endmodule

module issue3821;
  wire count_pin, res_pin, x_pin, loop_pin, supply_pin;
  reg released = 1'bz, pull_fixture = 1'bz;
  assign count_pin = released;
  assign (pull0, pull1) res_pin = pull_fixture;
  assign x_pin = released;
  assign loop_pin = released;
  assign supply_pin = released;
  issue3821_dut dut(count_pin, res_pin, x_pin, loop_pin, supply_pin);

  string filename = "work/issue3821.evcd";
  string line, state, strength0, strength1, expected;
  int fd, id, stamp;
  int records[5], last_stamp[5];

  initial begin
    #16 pull_fixture = 0;
    #2 pull_fixture = 1'bz;
  end

  initial begin
    // The delayed enable has settled to zero before dumping starts.
    #4 $dumpports(dut, filename);
    repeat (15) begin
      #1;
      #0;
      if ($sformatf("%v", count_pin) != "St0")
        $fatal(1, "count_pin changed strength or value at %0t", $time);
      if (loop_pin !== 1'b0)
        $fatal(1, "reconvergent source lost its definite path at %0t", $time);
      if ($sformatf("%v", supply_pin) != (($time >= 15 && $time < 17) ? "StX" : "St1"))
        $fatal(1, "unexpected supply_pin strength or value at %0t", $time);
    end
    $dumpportsflush(filename);
    fd = $fopen(filename, "r");
    if (!fd) $fatal(1, "cannot read EVCD");
    while ($fgets(line, fd)) begin
      if (line[0] == "#") begin
        if ($sscanf(line, "#%d", stamp) != 1)
          $fatal(1, "invalid EVCD timestamp %s", line);
      end else if (line[0] == "p") begin
        if ($sscanf(line, "p%s %s %s <%d", state, strength0, strength1, id) != 4 ||
            id < 0 || id > 4)
          $fatal(1, "invalid EVCD value record %s", line);
        if (records[id] && stamp <= last_stamp[id])
          $fatal(1, "out-of-order EVCD record at #%0d: %s", stamp, line);
        expected = "";
        case (id)
          0: case (stamp)
            4, 14: expected = "pL 6 0";
            8: expected = "pl 6 0";
          endcase
          1: case (stamp)
            4, 18: expected = "pL 3 0";
            // A pull-strength fixture wins against the attenuated DUT.
            16: expected = "pd 5 0";
          endcase
          2: case (stamp)
            4, 13: expected = "pf 0 0";
            7: expected = "pX 6 0";
            10: expected = "pL 6 0";
          endcase
          3: if (stamp == 4) expected = "pL 6 0";
          4: case (stamp)
            4, 17: expected = "ph 0 6";
            // The physical tran lowers supply to strong at this node.
            15: expected = "pX 6 6";
          endcase
        endcase
        if (line != $sformatf("%s <%0d\n", expected, id))
          $fatal(1, "at #%0d expected '%s' on <%0d, got %s", stamp, expected, id, line);
        records[id]++;
        last_stamp[id] = stamp;
      end
    end
    $fclose(fd);
    if (records[0] != 3 || records[1] != 3 || records[2] != 4 ||
        records[3] != 1 || records[4] != 3)
      $fatal(1, "missing EVCD records: count=%0d resistive=%0d unknown=%0d loop=%0d supply=%0d",
             records[0], records[1], records[2], records[3], records[4]);
    $display("PASSED");
  end
endmodule

// IEEE 1800-2017/2023 21.7.3.1 and 21.7.4.3.1-.2.
module issue3820_driver(inout wire p, input wire first, second);
  assign p = first;
  assign p = second;
endmodule

module issue3820_tied(.a(p), .b(p), drive);
  inout p;
  input drive;
  assign p = drive;
endmodule

module issue3820_dut(io, .slice(bus[3:2]));
  inout io;
  inout [4:0] bus;
  reg drive = 1'bz, extra = 1'bz;

  issue3820_driver child(io, drive, extra);
  // The two routes through fixed selects reach the very same driver.
  issue3820_tied tied(bus[3], bus[3], drive);
  // These part drivers share a resolver but cover neither monitored bit.
  assign bus[1] = 1'b1;
  assign bus[0] = 1'b0;

  initial begin
    #1 drive = 0;
    #2 drive = 1'bz;
    #1 drive = 0;
    #1 extra = 0;
    #1 extra = 1'bz;
  end
endmodule

module issue3820;
  wire scalar;
  wire [5:0] fixture_bus;
  reg drive = 1'bz;
  reg direct = 1'bz;
  issue3820_dut dut(scalar, fixture_bus[4:3]);
  issue3820_driver sibling(scalar, drive, 1'bz);
  issue3820_driver sibling_slice(fixture_bus[4], drive, 1'bz);
  assign dut.bus[3] = direct;

  int fd, stamp, declarations, scopes, scalar_records, vector_records;
  string line, ident, state, strength0, strength1, expected;
  string filename = "work/issue3820.evcd";

  initial begin
    $dumpports(dut, filename);
    #2 drive = 1;
    #2 drive = 1'bz;
    #3 direct = 0;
    #1 direct = 1'bz;
    #1;
    $dumpportsflush(filename);
    fd = $fopen(filename, "r");
    if (!fd) $fatal(1, "cannot read EVCD");

    while ($fgets(line, fd)) begin
      if (line.substr(0, 3) == "$var") begin
        case (declarations)
          0: expected = "$var port 1 <0 io $end\n";
          1: expected = "$var port [3:2] <1 bus $end\n";
          default: $fatal(1, "unexpected port declaration %s", line);
        endcase
        if (line != expected) $fatal(1, "wrong port declaration %s", line);
        declarations++;
      end else if (line.substr(0, 5) == "$scope") begin
        if (line != "$scope module issue3820.dut $end\n")
          $fatal(1, "unexpected scope %s", line);
        scopes++;
      end else if (line[0] == "#") begin
        if ($sscanf(line, "#%d", stamp) != 1)
          $fatal(1, "wrong EVCD timestamp %s", line);
      end else if (line[0] == "p") begin
        if ($sscanf(line, "p%s %s %s %s", state, strength0, strength1, ident) != 4)
          $fatal(1, "wrong EVCD value record %s", line);
        if (ident == "<0") begin
          if (stamp != scalar_records) $fatal(1, "unexpected scalar time %0d", stamp);
          case (stamp)
            0: expected = "pf 0 0 <0\n";
            1, 4, 6: expected = "pL 6 0 <0\n";
            2: expected = "pB 6 6 <0\n";
            3: expected = "pU 0 6 <0\n";
            5: expected = "pl 6 0 <0\n";
            default: $fatal(1, "unexpected scalar record %s", line);
          endcase
          scalar_records++;
        end else if (ident == "<1") begin
          if (stamp != (vector_records < 5 ? vector_records : vector_records + 2))
            $fatal(1, "unexpected slice time %0d", stamp);
          case (stamp)
            0: expected = "pfF 00 00 <1\n";
            1, 4, 8: expected = "pLF 60 00 <1\n";
            2: expected = "pBF 60 60 <1\n";
            3: expected = "pUF 00 60 <1\n";
            7: expected = "p0F 60 00 <1\n";
            default: $fatal(1, "unexpected slice record %s", line);
          endcase
          vector_records++;
        end else $fatal(1, "unexpected EVCD identifier %s", ident);
        if (line != expected) $fatal(1, "at #%0d expected %s got %s", stamp, expected, line);
      end
    end
    $fclose(fd);
    if (declarations != 2 || scopes != 1 || scalar_records != 7 || vector_records != 7)
      $fatal(1, "missing EVCD declarations or value changes");
    $display("PASSED");
  end
endmodule

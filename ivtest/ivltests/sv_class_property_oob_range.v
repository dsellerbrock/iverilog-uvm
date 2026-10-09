`timescale 1ns/1ps

class packed_desc_property;
  logic [1:0][7:0] value;
endclass

class packed_asc_property;
  logic [0:1][0:7] value;
endclass

module sv_class_property_oob_range;
  packed_desc_property desc;
  packed_asc_property asc;
  logic [3:0] part;
  integer base;
  logic [7:0] source;
  integer base_calls = 0;
  integer outer_calls = 0;
  integer errors = 0;

  function automatic integer select_base;
    base_calls = base_calls + 1;
    select_base = 6;
  endfunction

  function automatic integer select_outer;
    outer_calls = outer_calls + 1;
    select_outer = 0;
  endfunction

  initial begin
    desc = new;
    asc = new;
    source = 8'hA6;

    desc.value = 16'hA55A;
    base = 4;
    desc.value[0][base +: 4] = source;
    if (desc.value !== 16'hA56A) begin
      $display("FAIL in-range truncation: %h expected a56a", desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    base = 6;
    part = desc.value[0][base +: 4];
    if (part !== 4'bxx01) begin
      $display("FAIL descending read: %b expected xx01", part);
      errors++;
    end

    desc.value = 16'hA55A;
    desc.value[0][base +: 4] = source;
    if (desc.value !== 16'hA59A) begin
      $display("FAIL crossing truncation: %h expected a59a", desc.value);
      errors++;
    end

    desc.value[0][base +: 4] = 4'hF;
    if (desc.value !== 16'hA5DA) begin
      $display("FAIL descending write: %h expected a5da", desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    desc.value[0][base +: 4] |= 4'b0110;
    if (desc.value !== 16'hA5DA) begin
      $display("FAIL descending compound: %h expected a5da", desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    desc.value[0][base +: 4] <= 4'hF;
    #1;
    if (desc.value !== 16'hA5DA) begin
      $display("FAIL descending NBA: %h expected a5da", desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    base = -2;
    desc.value[0][base +: 4] = 4'hF;
    if (desc.value !== 16'hA55B) begin
      $display("FAIL negative crossing: %h expected a55b", desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    base = 10;
    part = desc.value[0][base +: 4];
    if (part !== 4'bxxxx) begin
      $display("FAIL wholly out-of-range read: %b expected xxxx", part);
      errors++;
    end
    desc.value[0][base +: 4] = 4'hF;
    if (desc.value !== 16'hA55A) begin
      $display("FAIL wholly out-of-range write: %h expected a55a", desc.value);
      errors++;
    end

    base = 'x;
    part = desc.value[0][base +: 4];
    if (part !== 4'bxxxx) begin
      $display("FAIL unknown-index read: %b expected xxxx", part);
      errors++;
    end
    desc.value[0][base +: 4] = 4'hF;
    if (desc.value !== 16'hA55A) begin
      $display("FAIL unknown-index write: %h expected a55a", desc.value);
      errors++;
    end

    asc.value = 16'hA55A;
    base = 6;
    asc.value[0][base +: 4] = 4'hF;
    if (asc.value !== 16'hA75A) begin
      $display("FAIL ascending write: %h expected a75a", asc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    base_calls = 0;
    outer_calls = 0;
    part = desc.value[select_outer()][select_base() +: 4];
    if (base_calls != 1 || outer_calls != 1 || part !== 4'bxx01) begin
      $display("FAIL side-effect select read: calls=%0d/%0d value=%b",
               base_calls, outer_calls, part);
      errors++;
    end

    desc.value = 16'hA55A;
    base_calls = 0;
    outer_calls = 0;
    desc.value[select_outer()][select_base() +: 4] = 4'hF;
    if (base_calls != 1 || outer_calls != 1) begin
      $display("FAIL selector evaluation counts: base=%0d outer=%0d",
               base_calls, outer_calls);
      errors++;
    end
    if (desc.value !== 16'hA5DA) begin
      $display("FAIL side-effect select write: %h expected a5da", desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    base_calls = 0;
    outer_calls = 0;
    desc.value[select_outer()][select_base() +: 4] |= 4'b0110;
    if (base_calls != 1 || outer_calls != 1 || desc.value !== 16'hA5DA) begin
      $display("FAIL side-effect compound: calls=%0d/%0d value=%h",
               base_calls, outer_calls, desc.value);
      errors++;
    end

    desc.value = 16'hA55A;
    base_calls = 0;
    outer_calls = 0;
    desc.value[select_outer()][select_base() +: 4] <= 4'hF;
    #1;
    if (base_calls != 1 || outer_calls != 1 || desc.value !== 16'hA5DA) begin
      $display("FAIL side-effect NBA: calls=%0d/%0d value=%h",
               base_calls, outer_calls, desc.value);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d errors)", errors);
  end
endmodule

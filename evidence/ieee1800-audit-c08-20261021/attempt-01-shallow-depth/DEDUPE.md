# Open and closed issue dedupe

Queries used `gh issue list --repo dsellerbrock/iverilog-uvm --state all`:

- Search `"shallow copy"`: open #616 (copy through a base handle aborts `vvp`) and #617 (object RNG state is not copied); closed #100 (class-property unpacked array element stores alias) and #101 (copy constructor as declaration initializer does not copy).
- Search `"new handle copy"`: no results.
- Search `"8.12"`: open #616 and #617; #836/#837 were unrelated clause-18 distribution issues. Closed #434 concerns captured handles in an automatic aggregate, not class shallow copy.

#616 is the exact S3 gap. #617 is a separate shallow-copy RNG gap already filed. Closed #100, #101, and #434 do not describe the S3 base-handle assertion.

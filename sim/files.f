+incdir+env
+incdir+tc
+incdir+th

env/pfe_if.sv
env/env_pkg.sv
env/protocol_sva.sv
th/dut_adapter.sv
tc/tc_pkg.sv

# Compile th/harness.sv after this filelist. All test classes are already
# registered by tc/tc_pkg.sv; select one at runtime with +UVM_TESTNAME.

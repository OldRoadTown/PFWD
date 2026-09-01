+incdir+env
+incdir+tc
+incdir+th

env/pfe_if.sv
env/env_pkg.sv
env/protocol_sva.sv
th/dut_adapter.sv

# Compile th/harness.sv and exactly one tc/*.sv in the same build. The harness
# selects the registered class by string and therefore does not depend on their
# relative source order.

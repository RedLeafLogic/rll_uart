# Primary system clock: 100 MHz (10 ns period, 50% duty cycle).
create_clock -name clk_sys -period 10.000 -waveform {0.000 5.000} \
    [get_ports {clk_i}]

# These inputs are asynchronous to clk_sys and enter dedicated synchronizers.
# Timing from each package pin to the first synchronizer stage is intentionally
# excluded; paths between synchronizer stages remain timed by clk_sys.
set_false_path -from [get_ports {srx_i cts_i dsr_i ri_i dcd_i}]

# External reset assertion is asynchronous. Reset release is synchronized
# internally before it reaches the UART functional state.
set_false_path -from [get_ports {nrst_i}]


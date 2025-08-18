
## Clock signal 100 MHz
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clock }] 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clock }] 

## Reset
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { reset_n }]

# Master Clock (mclk) 
# mclk[0] -> JA1 -> G13
set_property PACKAGE_PIN G13 [get_ports {mclk[0]}]
# mclk[1] -> JA7 -> D13 
set_property PACKAGE_PIN D13 [get_ports {mclk[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mclk[*]}]

# Serial Clock (sclk)
# sclk[0] -> JA2 -> B11
set_property PACKAGE_PIN B11 [get_ports {sclk[0]}] 
# sclk[1] -> JA8 -> B18
set_property PACKAGE_PIN B18 [get_ports {sclk[1]}] 
set_property IOSTANDARD LVCMOS33 [get_ports {sclk[*]}]

# Word Select (ws)
# ws[0] -> JA3 -> A11
set_property PACKAGE_PIN A11 [get_ports {ws[0]}] 
# ws[1] -> JA9 -> A18
set_property PACKAGE_PIN A18 [get_ports {ws[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ws[*]}]

# Serial Data In 
# sd_rx -> JA4 -> D12 
set_property PACKAGE_PIN D12 [get_ports sd_rx] 
set_property IOSTANDARD LVCMOS33 [get_ports sd_rx]

# Serial Data Out 
# sd_rx -> JA10 -> K16
set_property PACKAGE_PIN K16 [get_ports sd_tx] 
set_property IOSTANDARD LVCMOS33 [get_ports sd_tx]



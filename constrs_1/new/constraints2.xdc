## Clock (100 MHz)
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports i_Clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports i_Clk]

## Reset (SW0)
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports i_Reset_POR]

## USB-RS232 Interface (PC -> Basys over micro-USB)
## RsRx is the FPGA pin that receives UART from the USB-UART chip
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports i_uart_rx]
#set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports i_uart_rx]
## Packet received LED (LED0)
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports o_pkt_led]

## Anomaly LEDs (you used these three as individual outputs)
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports o_aqi_anomaly]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports o_temp_anomaly]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports o_light_anomaly]

## Temperature trend LEDs
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {o_temp_trend[0]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {o_temp_trend[1]}]

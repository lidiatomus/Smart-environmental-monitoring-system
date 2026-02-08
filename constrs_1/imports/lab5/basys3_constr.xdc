## ================================================================
## Basys3 rev B - Constraints for Final_Top
## ================================================================

## Clock (100 MHz)
set_property PACKAGE_PIN W5 [get_ports i_Clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_Clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports i_Clk]

## Reset (SW0)
set_property PACKAGE_PIN V17 [get_ports i_Reset_POR]
set_property IOSTANDARD LVCMOS33 [get_ports i_Reset_POR]

## UART RX on JA1
#set_property PACKAGE_PIN J1 [get_ports i_uart_rx]
#set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports i_uart_rx]
#set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports i_uart_rx]

## Packet received LED (LED0)
set_property PACKAGE_PIN U16 [get_ports o_pkt_led]
set_property IOSTANDARD LVCMOS33 [get_ports o_pkt_led]

## Anomaly LEDs
set_property PACKAGE_PIN E19 [get_ports o_temp_anomaly]
set_property IOSTANDARD LVCMOS33 [get_ports o_temp_anomaly]

set_property PACKAGE_PIN U19 [get_ports o_aqi_anomaly]
set_property IOSTANDARD LVCMOS33 [get_ports o_aqi_anomaly]

set_property PACKAGE_PIN V19 [get_ports o_light_anomaly]
set_property IOSTANDARD LVCMOS33 [get_ports o_light_anomaly]

## Temperature trend LEDs
set_property PACKAGE_PIN W18 [get_ports {o_temp_trend[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_temp_trend[0]}]

set_property PACKAGE_PIN U15 [get_ports {o_temp_trend[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_temp_trend[1]}]

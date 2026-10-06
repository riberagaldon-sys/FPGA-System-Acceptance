###############################################################################
# GX-BIDT Chapter 15 simulation / acceptance / report verification
# Vivado 2025.2, XC7A200T-FBG484-2
# Top: top_chapter15_acceptance_system
# Matrix + five-way/EC11 + touch/LCD configuration:
# Final BSW_CTRL1: 1,2,3,4,5,6,7,8,9 ON; 10 OFF
###############################################################################

set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports sys_clk]
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]

# 4x4 matrix keypad
set_property -dict {PACKAGE_PIN W22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[3]}]
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[2]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[1]}]
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[0]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {O_SWR[3]}]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {O_SWR[2]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {O_SWR[1]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {O_SWR[0]}]

# Five-way: A=DOWN, B=LEFT, C=RIGHT, D=UP, P=CENTER
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYA]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYB]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYC]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYD]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYP]

# EC11
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports EC_A]
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports EC_B]
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports EC_KEY]

# PS/2
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33 PULLUP true} [get_ports PS2_DATA]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports PS2_CLK]

# Capacitive touch
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports TOUCH_SCL]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS33} [get_ports TOUCH_SDA]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS33} [get_ports TOUCH_INT]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports TOUCH_RST]

# LCD RGB888
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {LCD_R[0]}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports {LCD_R[1]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33} [get_ports {LCD_R[2]}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {LCD_R[3]}]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {LCD_R[4]}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {LCD_R[5]}]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports {LCD_R[6]}]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports {LCD_R[7]}]

set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports {LCD_G[0]}]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports {LCD_G[1]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {LCD_G[2]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} [get_ports {LCD_G[3]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {LCD_G[4]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {LCD_G[5]}]
set_property -dict {PACKAGE_PIN E14 IOSTANDARD LVCMOS33} [get_ports {LCD_G[6]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports {LCD_G[7]}]

set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS33} [get_ports {LCD_B[0]}]
set_property -dict {PACKAGE_PIN L21 IOSTANDARD LVCMOS33} [get_ports {LCD_B[1]}]
set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports {LCD_B[2]}]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports {LCD_B[3]}]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {LCD_B[4]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {LCD_B[5]}]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports {LCD_B[6]}]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS33} [get_ports {LCD_B[7]}]

set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports LCD_CLK]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports LCD_HSYNC]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports LCD_VSYNC]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports LCD_DE]
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33} [get_ports LCD_BL]
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS33} [get_ports LCD_nRST]

set_property DRIVE 8 [get_ports {{LCD_R[*]} {LCD_G[*]} {LCD_B[*]} LCD_CLK LCD_HSYNC LCD_VSYNC LCD_DE LCD_BL LCD_nRST}]
set_property SLEW SLOW [get_ports {{LCD_R[*]} {LCD_G[*]} {LCD_B[*]} LCD_CLK LCD_HSYNC LCD_VSYNC LCD_DE LCD_BL LCD_nRST}]

# Five active-high yellow LEDs
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports {led[4]}]

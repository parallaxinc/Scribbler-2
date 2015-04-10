
'S2 monitor code version 2010.11.18

'---[Constants]----------------------------------------------------------------

CON

  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000
  LINE_THLD     = 32
  BAR_THLD      = 32
  OBSTACLE_THLD = 20

'---[Global Variables]---------------------------------------------------------

VAR

  long  CoinFlip, LeftMotor, RightMotor, MoveTime, FMStack[50]
  word  WheelSpace, FullCircle
  byte  LeftLight, CenterLight, RightLight, RefLights[3]
  byte  SeqCounter, ResetCount, LineCount, ObstacleCount, StallCount, ObstacleThld
  byte  LineThld, LeftLine, RightLine, LeftObstacle, RightObstacle, Self
  byte  Flag_green, Flag_yellow, Flag_orange, Flag_red, Flag_magenta, Flag_purple, Flag_blue, Stalled

'---[Object Declaration]-------------------------------------------------------

OBJ

  s2    : "S2"

'---[Start of Program]---------------------------------------------------------

PUB start

  s2.start
  's2.button_mode(true, true)
  if (s2.get_line_threshold <> s2#DEFAULT_LINE_THLD)
    LineThld := s2.get_line_threshold
  else
    LineThld := LINE_THLD 
  if (s2.get_obstacle_threshold <> s2#DEFAULT_OBSTACLE_THLD)
    ObstacleThld := s2.get_obstacle_threshold
  else
    ObstacleThld := OBSTACLE_THLD 
  waitcnt(cnt + 10_000_000) 
  cognew(FaultMonitor, @FMStack)
  outa[30]~~
  dira[30]~~
  \Green
  repeat

'---[Battery and Over-current Monitor Cog]-------------------------------------

PUB FaultMonitor : value

  value := $ffff
  waitcnt(cnt + 80_000_000)
  repeat
    value <#= s2.get_adc_results(s2#ADC_VBAT)
    if value > constant((700*2550)/(400*33))      '7.0V
      s2.set_led(s2#POWER,s2#BLUE)
    elseif value > constant((600*2550)/(400*33))  '6.0V
      s2.set_led(s2#POWER,$20)
    else
      s2.set_led(s2#POWER,s2#BLINK_BLUE)

'---[Main Program: Green]------------------------------------------------------

PUB Green

  repeat
    ReadLine
    ReadObstacle
    ReadLight
    Out("<")
    Hex(LeftLight, 2)
    Hex(CenterLight, 2)
    Hex(RightLight, 2)
    Hex((LeftLine & 1) << 3 | (RightLine & 1) << 2 | (LeftObstacle & 1) << 1 | RightObstacle & 1, 1)
    Out(">")
    Out(13)

'---[Read Light Sensors]-------------------------------------------------------

PRI ReadLight

  LeftLight := s2.light_sensor_log(s2#LEFT)
  CenterLight := s2.light_sensor_log(s2#CENTER)
  RightLight := s2.light_sensor_log(s2#RIGHT)

'---[Read the Line Sensors]----------------------------------------------------

PRI ReadLine

  LeftLine := 1 + s2.line_sensor(s2#LEFT, LineThld)
  RightLine := 1 + s2.line_sensor(s2#RIGHT, LineThld)

'---[Read Obstacle Sensors]----------------------------------------------------

PRI ReadObstacle | l, r

  l := s2.obstacle(s2#LEFT, ObstacleThld) & 1
  r := s2.obstacle(s2#RIGHT, ObstacleThld) & 1
  if (l == LeftObstacle and r == RightObstacle)
    ObstacleCount := (Obstaclecount + 1) <# 8
  else
    ObstacleCount := 1
    LeftObstacle := l
    RightObstacle := r

PRI Hex(value, digits)

'' Print a hexadecimal number in a field width given by digits.

  digits #>= ((>| value + 3) >> 2)
  if (digits > 8)
    repeat digits - 8
      out("0")
    digits := 8 
  value <<= 32 - (digits << 2)
  repeat digits
    Out(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))

PRI Out(txbyte) | timer

    txbyte := (txbyte | $300) << 2
    timer := cnt
    repeat 11
      waitcnt(timer += constant(80_000_000 / 9600))
      outa[30] := ((txbyte >>= 1) & 1)  

'---[End of Program]-----------------------------------------------------------
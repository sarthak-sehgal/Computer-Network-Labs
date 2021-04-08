# create simulator
set ns [new Simulator]

# setup tracing
set f0 [open udp_drop.tr w]
# set f1 [open tcp_jitter.tr w]
set nf [open out.nam w]
$ns namtrace-all $nf
set tf [open outall.tr w]
$ns trace-all $tf

# create nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]

# connect nodes
$ns duplex-link $n0 $n2 2Mb 10ms DropTail
$ns duplex-link $n1 $n2 2Mb 10ms DropTail
$ns duplex-link $n2 $n3 2Mb 10ms DropTail

# setup queue limit
$ns queue-limit $n2 $n3 5

# define finish procedure
proc finish {} {
    global f0 nf tf ns
    $ns flush-trace
    close $f0
    # close $f1
    close $nf
    close $tf
    exec awk -f calc_jitter.awk outall.tr > tcp_jitter.tr
    exec xgraph udp_drop.tr -geometry 800x400 &
    exec xgraph tcp_jitter.tr -geometry 800x400 &
    # exec nam out.nam &
    exit 0
}

# define record analytics procedure
proc record_udp_drop {} {
    global sink0 f0
    
    set ns [Simulator instance]
    
    set time .5

    set now [$ns now]
    
    set lostUdp [$sink0 set nlost_]
    # bandwidth in Mbit/s
    puts $f0 "$now $lostUdp"

    $sink0 set nlost_ 0

    $ns at [expr $now+$time] "record_udp_drop"
}

# proc record_tcp_jitter { last_pkt_time } {
#     global sink1 f1
    
#     set ns [Simulator instance]
    
#     set time .05

#     set now [$ns now]

#     set tcp_pkt_time [$sink1 set bytes_]
#     puts $f1 "$now [expr $tcp_pkt_time - $last_pkt_time]"

#     $ns at [expr $now+$time] "record_tcp_jitter $tcp_pkt_time"
# }

# attach UDP agents & traffic to 0->2 link
set udp0 [new Agent/UDP]
$ns attach-agent $n0 $udp0
set sink0 [new Agent/LossMonitor]
$ns attach-agent $n3 $sink0
set cbr [new Application/Traffic/CBR]
$cbr set packetSize_ 500
$cbr set interval_ 0.005
$cbr attach-agent $udp0
$ns connect $udp0 $sink0

# attach TCP agents & traffic to 1->2 link
set tcp0 [new Agent/TCP]
$ns attach-agent $n1 $tcp0
set sink1 [new Agent/TCPSink]
$ns attach-agent $n3 $sink1
set ftp [new Application/FTP]
$ftp set packetSize_ 500
$ftp set interval_ 0.005
$ftp attach-agent $tcp0
$ns connect $tcp0 $sink1

# log & run
$ns at 0.0 "record_udp_drop"
# $ns at 0.0 "record_tcp_jitter 0"
$ns at 0.0 "$ftp start"
$ns at 5.0 "$cbr start"
$ns at 10.0 "$ftp stop"
$ns at 10.0 "$cbr stop"
$ns at 15 "finish"

$ns run
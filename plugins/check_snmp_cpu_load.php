<?php

# A Munro: 30 Mar 2016: pnp4nagios template for check_snmp_cpu_load.pl.

# A Munro: 27 Aug 2015: Tweaks to increase no cpus per graph to 8 (from 4). 
# Adapt $no_cpu_per_graph, and if you want more then 8, add more colours
# and add more $line[x] vars.

# Define some colors

$red        = '#FF0000';
$magenta    = '#FF00FF';
$navy       = '#000080';
$green      = '#54EC48';
$darkgreen  = '#24BC14';
$yellow     = '#FFFF00';
$orangered  = '#FF4500';
$darkred    = '#8B0000';
$blue       = '#0000FF';
$darkblue   = '#000099';
$darkorange = '#FF8C00';
$lightpurp  = '#7648EC';
$darkpurp   = '#4D18E4';

$line[1]     = $darkgreen;
$line[2]     = $magenta;
$line[3]     = $darkorange;
$line[4]     = $darkred;
$line[5]     = $orangered;
$line[6]     = $lightpurp;
$line[7]     = $green;
$line[8]     = $navy;

# Define some initial variables

$counter1  = 2;
$counter2  = 2;
$cpu_number = 0;
$line_no = 1;
$graph_complete = 0;
$no_cpu_per_graph = 8;

# Replace underscores in services descriptions

$servicedesc = str_replace("_", " ", $servicedesc);
$no_cpu_per_graph = $no_cpu_per_graph + 2;

# Main logic

foreach ($DS as $i)
        {
        if ($i == 1)
           {
           # Well 1 means CPU average
      
           $ds_name[1] = "CPU Average";
           $opt[1] = '--vertical-label % --lower-limit 0 --upper-limit 100  --title "' . $hostname . ' / ' . $servicedesc . '"';

           $def[1]  = "DEF:cpu_avg=$RRDFILE[$i]:$DS[$i]:AVERAGE ";

           $def[1] .= "LINE1:cpu_avg$line[1]:\"$NAME[$i]\" ";
           $def[1] .= "GPRINT:cpu_avg:LAST:\"%3.4lf $UNIT[$i] LAST \" ";
           $def[1] .= "GPRINT:cpu_avg:MAX:\"%3.4lf $UNIT[$i] MAX \" ";
           $def[1] .= "GPRINT:cpu_avg:AVERAGE:\"%3.4lf $UNIT[$i] AVERAGE \\n\" ";

           $def[1] .= "HRULE:$WARN[1]#FFFF00:\"Warning \: $WARN[1] % \\n\" " ;
           $def[1] .= "HRULE:$CRIT[1]#FF0000:\"Critical\: $CRIT[1] % \" " ;
           }
        else
           {
           if ($counter2 == $no_cpu_per_graph)
              {
              $counter1++;
              $counter2  = 2;
              $line_no = 1;
           }
      
           if ($counter2 == 2)
              {
              $graph_complete = 1;
              $old_cpu_number = $cpu_number;
              $opt[$counter1] = '--vertical-label % --lower-limit 0 --upper-limit 100  --title "' . $hostname . ' / ' . $servicedesc . '"';

              $ds_name[$counter1] = "cpu$old_cpu_number - cpu$cpu_number";
              $def[$counter1]  = "DEF:cpu$cpu_number=$RRDFILE[$i]:$DS[$i]:AVERAGE ";
              }
           else
              {
              $ds_name[$counter1] = "cpu$old_cpu_number - cpu$cpu_number";
              $def[$counter1] .= "DEF:cpu$cpu_number=$RRDFILE[$i]:$DS[$i]:AVERAGE ";
           }

           $def[$counter1] .= "LINE1:cpu$cpu_number$line[$line_no]:\"$NAME[$i]\" ";
           $def[$counter1] .= "GPRINT:cpu$cpu_number:LAST:\"%3.4lf $UNIT[$i] LAST \" ";
           $def[$counter1] .= "GPRINT:cpu$cpu_number:MAX:\"%3.4lf $UNIT[$i] MAX \" ";
           $def[$counter1] .= "GPRINT:cpu$cpu_number:AVERAGE:\"%3.4lf $UNIT[$i] AVERAGE \\n\" ";

           if ($counter2 == ($no_cpu_per_graph - 1))
              {
              $def[$counter1] .= "HRULE:$WARN[1]#FFFF00:\"Warning \: $WARN[1] % \\n\" " ;
              $def[$counter1] .= "HRULE:$CRIT[1]#FF0000:\"Critical\: $CRIT[1] % \" " ;
              $graph_complete = 0;
           }

           $cpu_number++;
           $counter2++;
           $line_no++;
        }
}

if ($graph_complete == 1)
   {
   if ($cpu_number == 1)
      {
      # In case you have only one(!) CPU the loop will not work and therefore
      # $ds_name has to be added here. 
      $ds_name[$counter1] = "cpu0";
   }
   $def[$counter1] .= "HRULE:$WARN[1]#FFFF00:\"Warning \: $WARN[1] % \\n\" " ;
   $def[$counter1] .= "HRULE:$CRIT[1]#FF0000:\"Critical\: $CRIT[1] % \" " ;
}
?>

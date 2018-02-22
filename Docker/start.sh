#!/bin/bash
nohup Rscript /opt/DETECT/ShinyApp/app.R /opt/DETECT/ShinyApp/DETECT_02222017.mapping_stats.txt > nohup.log 2>&1 
sleep 10

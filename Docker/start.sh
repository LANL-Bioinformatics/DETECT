#!/bin/bash
nohup Rscript /opt/DETEQT/ShinyApp/app.R /opt/DETEQT/ShinyApp/DETEQT_02222017.mapping_stats.txt > nohup.log 2>&1 
sleep 10

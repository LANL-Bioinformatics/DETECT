#!/usr/bin/env Rscript
           
# load library
library(plotly)
library(htmlwidgets)

args <- commandArgs(trailingOnly = TRUE)
# print provided args
# print(paste("provided args: ", args))

# input arguments
stats_table_file <-args[1]
run_stats_table_file <-args[2]
out_prefix<-args[3]
Quality_Calculation_cutoff<-args[4]
Depth_of_coverage_cutoff<-args[5]

# check input
if ( !file.exists(stats_table_file) ){
  cat( " ./DETEQT_plot.R  targetedNGS.mapping_stats.txt targetedNGS.run_stats.txt out_prefix Quality_Calculation_cutoff Depth_of_coverage_cutoff\n")
  quit(save="no")
}

# default values
if (!exists("out_prefix") || is.na(out_prefix) ){out_prefix<-"targetedNGS"}
if (!exists("Quality_Calculation_cutoff")|| is.na(Quality_Calculation_cutoff)){Quality_Calculation_cutoff<-0.95^4}
if (!exists("Depth_of_coverage_cutoff")|| is.na(Depth_of_coverage_cutoff)){Depth_of_coverage_cutoff<-10^3}

Quality_Calculation_cutoff<-as.numeric(Quality_Calculation_cutoff)
Depth_of_coverage_cutoff<-as.numeric(Depth_of_coverage_cutoff)

# def.par <- par(no.readonly = TRUE) # default 
options(bitmapType="cairo")
stats_table<-read.table(file=stats_table_file,header=TRUE,stringsAsFactors=FALSE)

run_stats_table<-read.table(file=run_stats_table_file,header=TRUE,stringsAsFactors=FALSE)
# add Percent_Run column into table
if (length(run_stats_table$Percent_Run)==0){
	run_stats_table$Percent_Run <- run_stats_table$Prefilter_Reads/sum(run_stats_table$Prefilter_Reads)
	#file.remove(run_stats_table_file)
	write.table(arrange(run_stats_table,SampleID),file=run_stats_table_file,sep="\t",row.names = FALSE, quote = FALSE)
}

report_file<-paste(out_prefix,".report.txt",sep="");
report_file<-sub("/reports/","/stats/",report_file)
report_table<-stats_table[,c("SampleID","Target","Determination","Depth_Mean","Quality_Calculation")]
non_negative_report_table<-report_table[-c(which(report_table$Determination=="Negative")),]
non_negative_report_table<-arrange(non_negative_report_table, desc(Determination), desc(Depth_Mean))
write.table(non_negative_report_table,file=report_file,sep="\t",row.names = FALSE, quote = FALSE)

# Remove extra header
# stats_table<-stats_table[-c(which(stats_table$Determination=="Determination")),]

# Character to numeric
# stats_table$Quality_Calculation<-as.numeric(stats_table$Quality_Calculation)
# stats_table$Depth_Mean<-as.numeric(stats_table$Depth_Mean)
# stats_table$Coverage<-as.numeric(stats_table$Coverage)
# stats_table$Identity<-as.numeric(stats_table$Identity)
# stats_table$BaseQ_mean<-as.numeric(stats_table$BaseQ_mean)
# stats_table$MapQ_mean<-as.numeric(stats_table$MapQ_mean)
# stats_table$Match_BaseQ_mean<-as.numeric(stats_table$Match_BaseQ_mean)
# stats_table$Mismatch_BaseQ_mean<-as.numeric(stats_table$Mismatch_BaseQ_mean)

# Order Dtermination (Positive, Indeterminate, Negative) for Boxplots
new_levels<-sort(unique(stats_table$Determination),decreasing=TRUE)
if(grep("Negative",new_levels)){new_levels<-c(new_levels[-grep("Negative",new_levels)],"Negative")}
stats_table$Determination<-factor(stats_table$Determination,levels=new_levels)

stats_table_with_none0_q<-subset(stats_table,Quality_Calculation>0.01)

# boxplot for each interested stats
#m <- list(l = 50,r = 50, b = 50,t = 50, pad = 4 )
x_property <- list(title="")
title_font<-list(size=12)
p1<-plot_ly(stats_table,y=~Quality_Calculation,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(range=c(0,1),title="Calcuation",titlefont=title_font),xaxis=x_property) 
p2<-plot_ly(stats_table,y=~Depth_Mean+0.1,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(title="Depth",type="log",titlefont=title_font),xaxis=x_property) 
p3<-plot_ly(stats_table,y=~Coverage,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(range=c(0,1),title="Linear Coverage",titlefont=title_font),xaxis=x_property) 
p4<-plot_ly(stats_table,y=~Identity,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(range=c(0,1),title="Identity",titlefont=title_font),xaxis=x_property) 
p5<-plot_ly(stats_table,y=~BaseQ_mean,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(range=c(0,41),title="Mean BaseQ",titlefont=title_font),xaxis=x_property) 
p6<-plot_ly(stats_table,y=~MapQ_mean,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(title="Mean MapQ",titlefont=title_font),xaxis=x_property) 
p7<-plot_ly(stats_table,y=~Match_BaseQ_mean,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(range=c(0,41),title="Mean Match BaseQ",titlefont=title_font),xaxis=x_property) 
p8<-plot_ly(stats_table,y=~Mismatch_BaseQ_mean,x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = FALSE) %>% 
  layout(yaxis=list(range=c(0,41),title="Mean MisMatch BaseQ",titlefont=title_font),xaxis=x_property) 

# use subplot to show all boxplots in a page
quality_plot<-subplot(p1,p2,p3,p4,p5,p6,p7,p8,nrows = 4, shareX = TRUE,margin = 0.05,titleY=TRUE)


# sample plot

marker<-list(size=10)

ylim<-c(-0.1,1)
xlim<-c(-1,7)
y_property<-list(range=ylim,title="Quality Calcuation")
x_property<-list(range=xlim,title="Depth",type="log")
y_cutoff<-Quality_Calculation_cutoff
x_cutoff<-Depth_of_coverage_cutoff
H_line<-list(type = "line", line = list(color = "pink",dash = "dash" ), x0=0, x1=10^7, y0=y_cutoff, y1=y_cutoff, xref = "x", yref = "y" )
V_line<-list(type = "line", line = list(color = "pink",dash = "dash" ), x0=x_cutoff, x1=x_cutoff, y0=0, y1=1, xref = "x", yref = "y" )
neg<-list(x=-0.5,y=Quality_Calculation_cutoff-0.1,text="NEG",font=list(color="red",size=12),xref="x",yref="y",ax=0,ay=0)
ind1<-list(x=-0.5,y=Quality_Calculation_cutoff+0.1,text="IND-Depth",font=list(color="orange",size=12),xref="x",yref="y",ax=0,ay=0)
ind2<-list(x=6.5,y=Quality_Calculation_cutoff-0.1,text="IND-Qual",font=list(color="orange",size=12),xref="x",yref="y",ax=0,ay=0)
pos<-list(x=6.5,y=Quality_Calculation_cutoff+0.1,text="POS",font=list(color="blue",size=12),xref="x",yref="y",ax=0,ay=0)

table_for_plot <- stats_table_with_none0_q
if (nrow(stats_table_with_none0_q) == 0){
	table_for_plot <- stats_table
}

sample_plot <- plot_ly(table_for_plot,y=~Quality_Calculation,x=~Depth_Mean+0.1,type='scatter',mode='markers',color=~SampleID,marker=marker,hoverinfo = 'text', text = ~paste('Sample: ',SampleID, '</br> Target: ', Target, '</br> Depth: ', Depth_Mean,'</br> Calculation: ', Quality_Calculation)) %>% 
  layout(yaxis=y_property,xaxis=x_property,shapes=c(list(H_line),list(V_line)),annotations = c(list(neg),list(ind1),list(ind2),list(pos)))

target_plot <- plot_ly(table_for_plot,y=~Quality_Calculation,x=~Depth_Mean+0.1,type='scatter',mode='markers',color=~Target,marker=marker,hoverinfo = 'text', text = ~paste('Sample: ',SampleID, '</br> Target: ', Target, '</br> Depth: ', Depth_Mean,'</br> Calculation: ', Quality_Calculation)) %>% 
  layout(yaxis=y_property,xaxis=x_property,shapes=c(list(H_line),list(V_line)),annotations = c(list(neg),list(ind1),list(ind2),list(pos)))

# output as html files
suppressWarnings(saveWidget(quality_plot, paste0(out_prefix,"_quality_report.html"),selfcontained=FALSE))
suppressWarnings(saveWidget(sample_plot, paste0(out_prefix,"_sample_plot.html"),selfcontained=FALSE))
suppressWarnings(saveWidget(target_plot, paste0(out_prefix,"_target_plot.html"),selfcontained=FALSE))

# output png files if webshot packages is installed
if('webshot' %in% rownames(installed.packages()) == TRUE){
	require(webshot)
	webshot(paste0(out_prefix,"_quality_report.html"), file = paste0(out_prefix,"_quality_report.png"))
	webshot(paste0(out_prefix,"_sample_plot.html"), file = paste0(out_prefix,"_sample_plot.png"))
	webshot(paste0(out_prefix,"_target_plot.html"), file = paste0(out_prefix,"_target_plot.png"))
}


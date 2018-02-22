#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
stats_table_file <-args[1]
Quality_Calculation_cutoff <-args[2]
Depth_of_coverage_cutoff <-args[3]
port <-args[4]

if (length(args)==0) {
  cat( "Rscript ./app.R  mapping_stats.txt  Quality_Calculation_cutoff  Depth_of_coverage_cutoff port 
  
        Default Value
        Quality_Calculation_cutoff: 0.95^4
        Depth_of_coverage_cutoff: 1000
        port: 3838\n")
} 

if ( !file.exists(stats_table_file) ){
  stats_table_file<-"DETECT_02222017.mapping_stats.txt"
}

if (!exists("port") || is.na(port)){
  port<-3838
}else{
  port<-as.numeric(port)
}

if (!exists("Quality_Calculation_cutoff") || is.na(Quality_Calculation_cutoff)){
  Quality_Calculation_cutoff<-0.95^4
}else{
  Quality_Calculation_cutoff<-as.numeric(Quality_Calculation_cutoff)
}

if (!exists("Depth_of_coverage_cutoff") || is.na(Depth_of_coverage_cutoff)){
  Depth_of_coverage_cutoff<-1000
}else{
  Depth_of_coverage_cutoff<-as.numeric(Depth_of_coverage_cutoff)
}

library(shiny)
library(plotly)
library(DT)

read_file<-function(file){
  table<-read.table(file=file,header=TRUE,stringsAsFactors=FALSE)
  new_levels<-sort(unique(table$Determination),decreasing=TRUE)
  if(grep("Negative",new_levels)){new_levels<-c(new_levels[-grep("Negative",new_levels)],"Negative")}
  table$Determination<-factor(table$Determination,levels=new_levels)
  
  return(table)
}

stats_table <- read_file(stats_table_file)



sampleIDs <- sort(unique(stats_table$SampleID));
targetIDs <- sort(unique(stats_table$Target));
colNames<-colnames(stats_table)
noNumericCol<-c("SampleID","Target","Determination")
NumericCol<-colNames [! colNames %in% noNumericCol]


ui<-fluidPage(
  
  # Application title
  titlePanel("TargetedNGS Report"),
  
  # Sidebar with a slider input for number of bins 
  sidebarLayout(
    sidebarPanel(
       selectInput("color_by",
                   "Color By",
                    choices = c("SampleID","Target"),
                    multiple = FALSE),
       numericInput("depth_cutoff",
                   "Depth of Coverage Cutoff:",
                   min = 0,
                   max = 20000,
                   value = Depth_of_coverage_cutoff,
                   step=500),
       sliderInput("qc_cut",
                   "Quality Calculation Cutoff:",
                   min = 0,
                   max = 1,
                   value = Quality_Calculation_cutoff),
       selectInput("sampleIDs",
                   "Sample ID",
                   choices = sampleIDs,
                   multiple = TRUE),
       selectInput("targetIDs",
                   "Target ID",
                   choices = c("",targetIDs),
                   multiple = FALSE)
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      plotlyOutput("distPlot")
    )
  ),
  hr(),
  sidebarLayout(
    sidebarPanel(
      selectInput("BoxplotMatric",
                  "Boxplot Matric ID",
                  choices = c("",NumericCol),
                  selected = "Quality_Calculation"
                  )
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      plotlyOutput("boxplot")
      #tableOutput("boxplot")
    )
  ),
  hr(),
  fluidRow(
    column(width=12,style='padding:1em;',
      DT::dataTableOutput('tbl')
    )
  )
  
)


server<- function(input, output,session) {
  values <- reactiveValues(df_data = stats_table)
  observe({
  
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['file']])) {
      #updateTextInput(session, "text", value = query[['file']])
      stats_table<-read.table(file=query[['file']],header=TRUE,stringsAsFactors=FALSE)
      sampleIDs <- sort(unique(stats_table$SampleID));
      targetIDs <- sort(unique(stats_table$Target));
      colNames<-colnames(stats_table)
      noNumericCol<-c("SampleID","Target","Determination")
      NumericCol<-colNames [! colNames %in% noNumericCol]
      updateSelectInput(session,"sampleIDs",choices = sampleIDs)
      updateSelectInput(session,"targetIDs",choices = c("",targetIDs))
      updateSelectInput(session,"BoxplotMatric",choices = NumericCol, selected = "Quality_Calculation")
      values$df_data<-stats_table
    }
  
    observeEvent(input$qc_cut, {
      stats_table$Determination[which(stats_table$Depth_Mean>=input$depth_cutoff & stats_table$Quality_Calculation>=input$qc_cut)] = "Positive"
      stats_table$Determination[which(stats_table$Depth_Mean>=input$depth_cutoff & stats_table$Quality_Calculation<input$qc_cut)] = "Indeterminate-Quality"
      stats_table$Determination[which(stats_table$Depth_Mean<input$depth_cutoff & stats_table$Quality_Calculation>=input$qc_cut)] = "Indeterminate-Depth"
      stats_table$Determination[which(stats_table$Depth_Mean<input$depth_cutoff & stats_table$Quality_Calculation<input$qc_cut)] = "Negative"
      values$df_data<-stats_table
    })
    observeEvent(input$depth_cutoff, {
      stats_table$Determination[which(stats_table$Depth_Mean>=input$depth_cutoff & stats_table$Quality_Calculation>=input$qc_cut)] = "Positive"
      stats_table$Determination[which(stats_table$Depth_Mean>=input$depth_cutoff & stats_table$Quality_Calculation<input$qc_cut)] = "Indeterminate-Quality"
      stats_table$Determination[which(stats_table$Depth_Mean<input$depth_cutoff & stats_table$Quality_Calculation>=input$qc_cut)] = "Indeterminate-Depth"
      stats_table$Determination[which(stats_table$Depth_Mean<input$depth_cutoff & stats_table$Quality_Calculation<input$qc_cut)] = "Negative"
      values$df_data<-stats_table
    })
  
  
  
    output$distPlot <- renderPlotly({
      marker<-list(size=10)
      ylim<-c(-0.1,1)
      xlim<-c(-1,7)
      plot_title<-""
      y_property<-list(range=ylim,title="Quality Calcuation")
      x_property<-list(range=xlim,title="Depth",type="log")
      y_cutoff<-input$qc_cut
      x_cutoff<-input$depth_cutoff
      color_by<-input$color_by
      H_line<-list(type = "line", line = list(color = "pink",dash = "dash" ), x0=0, x1=10^7, y0=y_cutoff, y1=y_cutoff, xref = "x", yref = "y" )
      V_line<-list(type = "line", line = list(color = "pink",dash = "dash" ), x0=x_cutoff, x1=x_cutoff, y0=0, y1=1, xref = "x", yref = "y" )
      neg<-list(x=-0.5,y=input$qc_cut-0.1,text="NEG",font=list(color="red",size=12),xref="x",yref="y",ax=0,ay=0)
      ind1<-list(x=-0.5,y=input$qc_cut+0.1,text="IND-Depth",font=list(color="orange",size=12),xref="x",yref="y",ax=0,ay=0)
      ind2<-list(x=6.5,y=input$qc_cut-0.1,text="IND-Qual",font=list(color="orange",size=12),xref="x",yref="y",ax=0,ay=0)
      pos<-list(x=6.5,y=input$qc_cut+0.1,text="POS",font=list(color="green",size=12),xref="x",yref="y",ax=0,ay=0)
      df_data_none0_q<-subset(values$df_data,Quality_Calculation>0.01)
      if (length(input$sampleIDs)>0){
        df_data_none0_q<-subset(df_data_none0_q, SampleID %in% input$sampleIDs)
      }
      if (input$targetIDs != ""){
        df_data_none0_q<-subset(df_data_none0_q, Target == input$targetIDs)
      }
      if (length(df_data_none0_q$Quality_Calculation)==0){
        df_data_none0_q[1,]=rep(0,length(df_data_none0_q))
        plot_title<-"No Data Available"
      }
      plot_ly(df_data_none0_q,y=~Quality_Calculation,x=~Depth_Mean+0.1,type='scatter',mode='markers',color=df_data_none0_q[[color_by]],marker=marker,hoverinfo = 'text', text = ~paste('Sample: ',SampleID, '</br> Target: ', Target, '</br> Depth: ', Depth_Mean,'</br> Calculation: ', Quality_Calculation)) %>% 
        layout(title=plot_title,yaxis=y_property,xaxis=x_property,shapes=c(list(H_line),list(V_line)),annotations = c(list(neg),list(ind1),list(ind2),list(pos)))
    
    })
    output$boxplot <- renderPlotly({
  
      x_property <- list(title="")
      title_font<-list(size=12)
      plot_title<-""
      box_yaxis<-input$BoxplotMatric
      df_data_sub<-subset(values$df_data,Quality_Calculation>0.01)
      if (length(input$sampleIDs)>0){
        df_data_sub<-subset(df_data_sub, SampleID %in% input$sampleIDs)
      }
      if (input$targetIDs != ""){
        df_data_sub<-subset(df_data_sub, Target == input$targetIDs)
      }
      if (length(df_data_sub$Quality_Calculation)==0){
        plot_title<-"No Data Available"
      }
      boxplotTable<-df_data_sub[,c("SampleID",box_yaxis,"Determination"), drop = FALSE]
    
      ylog<-""
      if (sum(as.numeric(boxplotTable[[box_yaxis]])) > 10000){
        ylog<-"log"
      }
      m <- list( l = 50, r = 30, b = 100,   t = 30,   pad = 4 )
      plot_ly(boxplotTable,y=boxplotTable[[box_yaxis]],x=~Determination,boxpoints = "all",pointpos=0,type='box',color=~Determination,showlegend = TRUE) %>% 
        layout(title=plot_title,yaxis=list(type=ylog,title=box_yaxis,titlefont=title_font),xaxis=x_property,margin =  m)
       #layout(yaxis=list(range=c(0,max(boxplotTable$box_yaxis)),title=box_yaxis,titlefont=title_font),xaxis=x_property) 
    
    })
    output$tbl <- DT::renderDataTable({
      df_data_sub<-subset(values$df_data, Determination != "Negative")
      if (length(input$sampleIDs)>0){
        df_data_sub<-subset(df_data_sub, SampleID %in% input$sampleIDs)
      }
      if (input$targetIDs != ""){
        df_data_sub<-subset(df_data_sub, Target == input$targetIDs)
      }
      datatable(df_data_sub[,c("SampleID","Target","Determination","Depth_Mean","Quality_Calculation"), drop = FALSE],
      			extensions = 'Buttons',
      			options = list(order=list(list(3, 'asc'),list(2,'asc')),pageLength = 10, dom = 'Bfrtip',buttons = c('copy', 'csv', 'pdf', 'print'))) %>% 
      			formatStyle( c('Target','Determination'),'Determination', color = styleEqual('Positive', c('red'))) %>%
      			formatStyle( 'SampleID','Determination', color = styleEqual('Positive', c('blue')))
    })
  
  }) 
  #endobserve
  
}

shinyApp(ui=ui,server=server, options = list(launch.browser=TRUE,port=port,host="0.0.0.0"))


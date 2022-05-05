smoltregApp <- function() {
  # GUI ---------------------------------------------------------------------
  ui <- fluidPage(
    titlePanel("Smoltreg data checker and converter."),
    sidebarLayout(
      sidebarPanel(
        p("Choose input file:"),
       #             a(href = "HOWTO.html", "HOWTO!"),
        fileInput("file1", "Upload Smoltreg file",
                  accept = c("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                            "application/vnd.ms-excel")),
       actionButton("listspecies", "List species"),
       actionButton("unknownspecies", "Unknown species")
      ),
      
      mainPanel(
        h1("Smoltreg file"),
        tableOutput("file1"),
        hr(),
        tableOutput("listspecies"),
        hr(),
        tableOutput("unknownspecies")
        
        )
      )
    )

    
  
  # Server ------------------------------------------------------------------------
    server <- function(input, output) {
    ##    source("config.R", encoding = "UTF-8")
    ##    source("functions.R", encoding = "UTF-8")
    require(Smoltreg)
    metadata <- reactive(read_meta(input$file1$datapath))
    fishdata <- reactive(read_fish(input$file1$datapath,
                                   dummy_tags = metadata()$dummy_tags))
    
    output$file1 <- renderTable({
      if (is.null(input$file1)) {
        return(data.frame(River = NA, Start = NA, End =  NA, N_fish = NA))
      }
#      metadata <<- read_meta(input$file1$datapath)
#      fishdata <<- read_fish(input$file1$datapath,
#                            dummy_tags = metadata$dummy_tags)
      infotab <- data.frame(River = metadata()$river,
                            Start = as.character(metadata()$startdate),
                            End = as.character(metadata()$enddate),
                            N_fish = nrow(fishdata()))
      return(infotab)}
    )
    
    output$listspecies <- renderTable({
      if (input$listspecies == 0 | is_odd(input$listspecies)) {
        return('Click "List species" button')
      }
        res <- mk_species_table(fishdata())
        return(res)
    })
    
    output$unknownspecies <- renderTable({
      if (input$unknownspecies == 0 | is_odd(input$unknownspecies)) {
        return('Click "Unknown species" button')
      }
      res <- mk_unknown_table(fishdata())
      return(res)
    })
    
    output$XLSXfile <- downloadHandler(
      filename = function() {paste0(tools::file_path_sans_ext(input$file1$name),
                                    "_sötebasen.xlsx")},
      content = function(file) {
        # Generate Excel in 'file' here.
        tmpDir <- tempdir()
        odir <- setwd(tmpDir)
        metadata <- read_meta(input$file1$datapath)
        fishdata <- read_fish(input$file1$datapath,
                              dummy_tags = metadata$dummy_tags)
        start_year <- as.numeric(format(metadata$startdate, "%Y"))
        end_year <- as.numeric(format(metadata$enddate, "%Y"))
        
        # We define "Insamling" as one season for one trap.
        # Start and stop year (Årtal och Årtal2) are set to the same year.
        Insamling <- data.frame(InsamlingID = 1,
                                Vatten = metadata$river,
                                Årtal = start_year,
                                Årtal2 = start_year,
                                Metod = metadata$Metod,
                                Ansvarig = metadata$Ansvarig,
                                Syfte = metadata$Syfte,
                                Sekretess = "Nej",
                                Signatur = metadata$Signatur
        )
        # Also "Ansträngning" is one season for one trap..
        Ansträngning <- data.frame(AnsträngningID = 1,
                                   InsamlingID = 1,
                                   AnstrTyp = metadata$Metod,
                                   AnstrPlats = metadata$loc_name,
                                   AnstrDatumStart = metadata$startdate,
                                   AnstrDatumSlut = metadata$enddate,
                                   AnstrS99TM_N_1 = metadata$N_coord,
                                   AnstrS99TM_E_1 = metadata$E_coord,
                                   Märkning = metadata$Märkning,
                                   SignAnstr = metadata$Signatur
        )
        ###
        ## Assume that catch_time == "00:00" equals missing time and set time to NA.
        catch_time <- format(fishdata$date_time, "%H:%M")
        catch_time <- ifelse(catch_time == "00:00", NA, catch_time)
        Individ <- data.frame(#IndividID = 1:nrow(fishdata),
          InsamlingId = 1,
          AnsträngningID = 1,
          FångstDatum = format(fishdata$date_time, "%Y-%m-%d"),
          FångstTid = catch_time,
          Art = fishdata$species,
          Åldersprov = ifelse(is.na(fishdata$genid), 'Nej', 'Ja'),
          Provkod = fishdata$genid,
          Längd1 = fishdata$length,
          Vikt1 = fishdata$weight,
          Behandling = event2Behandling(fishdata$event),
          Stadium = fishdata$smoltstat,
          MärkeNr = as.character(fishdata$pittag),
          Märkning = ifelse(is.na(fishdata$pittag),NA, metadata$Märkning),
          SignIndivid = metadata$Signatur,
          AnmIndivid = fishdata$comment
        )
        
        sheetnames <- c('Insamling', enc2utf8('Ansträngning'), 'Individ')
        l <- list(Insamling, Ansträngning, Individ)
        if (input$do_envdata) {
          envdata <- read_envdata(input$file1$datapath, metadata$startdate, metadata$enddate)
          Temperatur <- data.frame(InsamlingID = 1,
                                   MätDatum = envdata$date,
                                   Tempbotten = envdata$w_temp,
                                   Vattennivå = envdata$w_level,
                                   SignTemp = metadata$Signatur
          )
          sheetnames <- c(sheetnames, 'Temperatur')
          l <- c(l , list(Temperatur))
        }
        names(l) <- sheetnames
        writexl::write_xlsx(l, path = file)
        setwd(odir)
      },
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ) # End output$XLSXfile

    }
    shinyApp(ui, server)
}

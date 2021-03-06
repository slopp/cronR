
#' @title Launch an RStudio addin which allows to schedule an Rscript interactively.
#' @description Launch an RStudio addin which allows to schedule an Rscript interactively.
#' 
#' @param RscriptRepository path to the folder where R scripts will be copied to and launched. Defaults to the extdata folder in the cronR R library
#' @return the return of \code{\link[shiny]{runGadget}}
#' @export
#' @examples 
#' \dontrun{
#' cron_rstudioaddin()
#' }
cron_rstudioaddin <- function(RscriptRepository) {
  
  cron_current <- function(){
    x <- try(parse_crontab(), silent = TRUE)
    if(inherits(x, "try-error")){
      x <- list(cronR = character())
    }
    x
  }
  require("cronR")
  require("shiny")
  require("miniUI")
  require("shinyFiles")
  current_repo <- file.path(system.file("extdata", package="cronR"), "RscriptRepository.rds")
  if(missing(RscriptRepository)){
    if(file.exists(current_repo)){
      RscriptRepository <- readRDS(file = current_repo)
    }else{
      RscriptRepository <- system.file("extdata", package="cronR")
      RscriptRepository <- getwd()
      saveRDS(RscriptRepository, file = current_repo)
    }
  }
  
  check <- NULL
  
  ui <- miniUI::miniPage(
    # Shiny fileinput resethandler
    # shiny::tags$script('
    #                    Shiny.addCustomMessageHandler("resetFileInputHandler", function(x) {
    #                    var id = "#" + x + "_progress";
    #                    var idBar = id + " .bar";
    #                    $(id).css("visibility", "hidden");
    #                    $(idBar).css("width", "0%");
    #                    });
    #                    '),
    
    miniUI::gadgetTitleBar("Use cron to schedule your R script"),
    
    miniUI::miniTabstripPanel(
      miniUI::miniTabPanel(title = 'Upload and create new jobs', icon = shiny::icon("cloud-upload"),
                           miniUI::miniContentPanel(
                             #shiny::uiOutput('fileSelect'),
                             shiny::h4("Choose your Rscript"),
                             shinyFiles::shinyFilesButton('fileSelect', label='Select file', title='Choose your Rscript', multiple=FALSE),
                             shiny::br(),
                             shiny::br(),
                             shiny::fillRow(flex = c(3, 3),
                                            shiny::column(6,
                                                          shiny::div(class = "control-label", shiny::strong("Selected Rscript")),
                                                          shiny::verbatimTextOutput('currentfileselected'),
                                                          shiny::dateInput('date', label = "Launch date:", startview = "month", weekstart = 1, min = Sys.Date()),
                                                          shiny::textInput('hour', label = "Launch hour:", value = format(Sys.time() + 122, "%H:%M")),
                                                          shiny::radioButtons('task', label = "Schedule:", choices = c('ONCE', 'EVERY MINUTE', 'EVERY HOUR', 'EVERY DAY', 'EVERY WEEK', 'EVERY MONTH'), selected = "ONCE")
                                            ),
                                            shiny::column(6,
                                                          shiny::textInput('jobdescription', label = "Job description", value = "I execute things"),
                                                          shiny::textInput('jobtags', label = "Job tags", value = ""),
                                                          shiny::textInput('rscript_args', label = "Additional arguments to Rscript", value = ""),
                                                          shiny::textInput('jobid', label = "Job identifier", value = sprintf("job_%s", digest(runif(1)))),
                                                          shiny::textInput('rscript_repository', label = "Rscript repository path: launch & log location", value = RscriptRepository)
                                            ))
                           ),
                           miniUI::miniButtonBlock(border = "bottom",
                                                   shiny::actionButton('create', "Create job", icon = shiny::icon("play-circle"))
                           )
      ),
      miniUI::miniTabPanel(title = 'Manage existing jobs', icon = shiny::icon("table"),
                           miniUI::miniContentPanel(
                             shiny::fillRow(flex = c(3, 3),
                                            shiny::column(6,
                                                          shiny::h4("Existing crontab"),
                                                          shiny::actionButton('showcrontab', "Show current crontab schedule", icon = shiny::icon("calendar")),
                                                          shiny::br(),
                                                          shiny::br(),
                                                          shiny::h4("Show/Delete 1 specific job"),
                                                          shiny::uiOutput("getFiles"),
                                                          shiny::actionButton('showjob', "Show job", icon = shiny::icon("clock-o")),
                                                          shiny::actionButton('deletejob', "Delete job", icon = shiny::icon("remove"))
                                            ),
                                            shiny::column(6,
                                                          shiny::h4("Save crontab"),
                                                          shiny::textInput('savecrontabpath', label = "Save current crontab schedule to", value = file.path(Sys.getenv("HOME"), "my_schedule.cron")),
                                                          shiny::actionButton('savecrontab', "Save", icon = shiny::icon("save")),
                                                          shiny::br(),
                                                          shiny::br(),
                                                          shiny::h4("Load crontab"),
                                                          #shiny::uiOutput('cronload'),
                                                          shinyFiles::shinyFilesButton('crontabSelect', label='Select crontab schedule', title='Select crontab schedule', multiple=FALSE),
                                                          #shiny::div(class = "control-label", strong("Selected crontab")),
                                                          shiny::br(),
                                                          shiny::br(),
                                                          shiny::actionButton('loadcrontab', "Load selected schedule", icon = shiny::icon("load")),
                                                          shiny::br(),
                                                          shiny::br(),
                                                          shiny::verbatimTextOutput('currentcrontabselected')
                                            ))
                           ),
                           miniUI::miniButtonBlock(border = "bottom",
                                                   shiny::actionButton('deletecrontab', "Completely clear current crontab schedule", icon = shiny::icon("delete"))
                           )
      )
    )
  )
  
  # Server code for the gadget.
  server <- function(input, output, session) {
    volumes <- c('Current working dir' = getwd(), 'HOME' = Sys.getenv('HOME'), 'R Installation' = R.home(), 'Root' = "/")
    getSelectedFile <- function(inputui, default = "No R script selected yet"){
      f <- shinyFiles::parseFilePaths(volumes, inputui)$datapath
      f <- as.character(f)
      if(length(f) == 0){
        return(default)
      }else{
        if(length(grep(" ", f, value=TRUE))){
          warning(sprintf("Make sure the file you want to schedule (%s) does not contain spaces", f))
        }
      }
      f
    }
    # Ui element for fileinput
    shinyFiles::shinyFileChoose(input, id = 'fileSelect', roots = volumes, session = session)
    output$fileSelect <- shiny::renderUI({shinyFiles::parseFilePaths(volumes, input$fileSelect)})
    output$currentfileselected <- shiny::renderText({getSelectedFile(inputui = input$fileSelect)})
    #output$fileSelect <- shiny::renderUI({
    #  shiny::fileInput(inputId = 'file', 'Choose your Rscript',
    #            accept = c("R-bestand"),
    #            multiple = TRUE)
    #})
    shinyFiles::shinyFileChoose(input, id = 'crontabSelect', roots = volumes, session = session)
    output$crontabSelect <- shiny::renderUI({shinyFiles::parseFilePaths(volumes, input$crontabSelect)})
    output$currentcrontabselected <- shiny::renderText({basename(getSelectedFile(inputui = input$crontabSelect, default = ""))})
    # output$cronload <- shiny::renderUI({
    #   shiny::fileInput(inputId = 'crontabschedule', 'Load an existing crontab schedule & overwrite current schedule',
    #                    multiple = FALSE)
    # })
    
    # When path to Rscript repository has been changed
    shiny::observeEvent(input$rscript_repository, {
      RscriptRepository <<- normalizePath(input$rscript_repository, winslash = "/")
      if(file.exists(RscriptRepository) && file.info(RscriptRepository)$isdir == TRUE){
        saveRDS(RscriptRepository, file = current_repo)
      }else {
        message(sprintf("RscriptRepository %s does not exist, make sure this is an existing directory without spaces", RscriptRepository))
      }
    })
    
    ###########################
    # CREATE / OVERWRITE
    ###########################
    shiny::observeEvent(input$create, {
      shiny::req(input$task)
      #shiny::req(input$file)
      
      if(input$task == "EVERY MONTH" ){
        days <- as.integer(format(input$date, "%d"))
      }
      else if(input$task == "EVERY WEEK"){
        days <- as.integer(format(input$date, "%w"))
      }
      else {
        # get default value by setting days to null.
        days <- NULL
      }
      starttime <- input$hour
      rscript_args <- input$rscript_args
      frequency <- factor(input$task, 
                          levels = c('ONCE', 'EVERY MINUTE', 'EVERY HOUR', 'EVERY DAY', 'EVERY WEEK', 'EVERY MONTH'),
                          labels = c('once', 'minutely', 'hourly', 'daily', 'weekly', 'monthly'))
      frequency <- as.character(frequency)
      
      ##
      ## Copy the uploaded file from the webapp to the main folder to store the scheduled rscripts.
      ##
      if(length(grep(" ", RscriptRepository)) > 0){
        stop(sprintf("Make sure the RscriptRepository does not contain spaces, change argument %s to another location on your drive which contains no spaces", RscriptRepository))
      }
      runme <- getSelectedFile(inputui = input$fileSelect)
      myscript <- paste0(RscriptRepository, "/", basename(runme))
      if(runme != myscript){
        done <-  file.copy(runme, myscript, overwrite = TRUE)
        if(!done){
          stop(sprintf('Copying file %s to %s failed. Do you have access rights to %s?', file.path(runme, input$file$name), myscript, dirname(myscript)))
        }  
      }
      ##
      ## Make schedule task
      ##
      cmd <- sprintf("Rscript %s %s >> %s.log 2>&1", myscript, rscript_args, tools::file_path_sans_ext(myscript))
      if(frequency %in% c('minutely')){
        cron_add(command = cmd, frequency = frequency, id = input$jobid, tags = input$jobtags, description = input$jobdescription)  
      }else if(frequency %in% c('hourly')){
        cron_add(command = cmd, frequency = frequency, at = starttime, id = input$jobid, tags = input$jobtags, description = input$jobdescription)  
      }else if(frequency %in% c('daily')){
        cron_add(command = cmd, frequency = 'daily', at = starttime, id = input$jobid, tags = input$jobtags, description = input$jobdescription)  
      }else if(frequency %in% c('weekly')){
        cron_add(command = cmd, frequency = 'daily', days_of_week = days, at = starttime, id = input$jobid, tags = input$jobtags, description = input$jobdescription)  
      }else if(frequency %in% c('monthly')){
        cron_add(command = cmd, frequency = 'monthly', days_of_month = days, days_of_week = 1:7, at = starttime, id = input$jobid, tags = input$jobtags, description = input$jobdescription)  
      }else if(frequency %in% c('once')){
        message(sprintf("This is not a cron schedule but will launch: %s", sprintf('nohup %s &', cmd)))
        system(sprintf('nohup %s &', cmd))
      }
      
      # Reset ui inputs
      shiny::updateDateInput(session, inputId = 'date', value = Sys.Date())
      shiny::updateTextInput(session, inputId = "hour", value = format(Sys.time() + 122, "%H:%M"))
      shiny::updateRadioButtons(session, inputId = 'task', selected = "ONCE")
      shiny::updateTextInput(session, inputId = "jobid", value = sprintf("job_%s", digest(runif(1))))
      shiny::updateTextInput(session, inputId = "jobdescription", value = "I execute things")
      shiny::updateTextInput(session, inputId = "jobtags", value = "")
      shiny::updateTextInput(session, inputId = "rscript_args", value = "")
      # output$fileSelect <- shiny::renderUI({
      #   shiny::fileInput(inputId = 'file', 'Choose your Rscript',
      #                    accept = c("R-bestand"),
      #                    multiple = TRUE)
      # })
      #output$currentfileselected <- shiny::renderText({""})
      shiny::updateSelectInput(session, inputId="getFiles", choices = sapply(cron_current()$cronR, FUN=function(x) x$id))
    })
    
    ###########################
    # Schedule list
    ###########################
    output$getFiles <- shiny::renderUI({
      shiny::selectInput(inputId = 'getFiles', "Select job", choices = sapply(cron_current()$cronR, FUN=function(x) x$id))
    })
    ###########################
    # Show
    ###########################
    shiny::observeEvent(input$showcrontab, {
      cron_ls()
    })
    shiny::observeEvent(input$showjob, {
      cron_ls(input$getFiles)
    })
    ###########################
    # Save/Load/Delete
    ###########################
    shiny::observeEvent(input$savecrontab, {
      message(input$savecrontabpath)
      cron_save(file = input$savecrontabpath, overwrite = TRUE)
    })
    shiny::observeEvent(input$loadcrontab, {
      #cron_load(file = input$crontabschedule$datapath)
      f <- getSelectedFile(inputui = input$crontabSelect, default = "")
      message(f)
      if(f != ""){
        cron_load(file = f)
      }
      output$getFiles <- shiny::renderUI({
        shiny::selectInput(inputId = 'getFiles', "Select job", choices = sapply(cron_current()$cronR, FUN=function(x) x$id))
      })
    })
    shiny::observeEvent(input$deletecrontab, {
      cron_clear(ask = FALSE)
      output$getFiles <- shiny::renderUI({
        shiny::selectInput(inputId = 'getFiles', "Select job", choices = sapply(cron_current()$cronR, FUN=function(x) x$id))
      })
    })
    shiny::observeEvent(input$deletejob, {
      cron_rm(input$getFiles)
      output$getFiles <- shiny::renderUI({
        shiny::selectInput(inputId = 'getFiles', "Select job", choices = sapply(cron_current()$cronR, FUN=function(x) x$id))
      })
    })
    
    
    
    # Listen for the 'done' event. This event will be fired when a user
    # is finished interacting with your application, and clicks the 'done'
    # button.
    shiny::observeEvent(input$done, {
      # Here is where your Shiny application might now go an affect the
      # contents of a document open in RStudio, using the `rstudioapi` package.
      # At the end, your application should call 'stopApp()' here, to ensure that
      # the gadget is closed after 'done' is clicked.
      shiny::stopApp()
    })
  }
  
  # Use a modal dialog as a viewr.
  viewer <- shiny::dialogViewer("Cron job scheduler", width = 700, height = 800)
  #viewer <- shiny::paneViewer()
  shiny::runGadget(ui, server, viewer = viewer)
}


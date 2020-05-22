#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(shinydashboard)
library(redditor)
library(scales)
library(future)
options(shiny.sanitize.errors = FALSE)
con <- postgres_connector()

get_count <- function(table_name = "mat_comments_by_second", min_date = "2020-05-03", max_date = Sys.Date()) {
  con <- postgres_connector()
  table_name <- tbl(con, in_schema("public", table_name)) %>% my_collect()
  on.exit(dbDisconnect(conn = con))

  total_sum <- sum(table_name$n_observations)
  total_in_last_hour <- table_name %>%
    filter(created_utc > local(now(tzone = "UTC") - hours(1))) %>%
    count() %>%
    pull(n)

  comments_gathered <- comma_format()(total_sum)
  total_in_last_hour <- comma_format()(total_in_last_hour)

  list(comments_gathered = comments_gathered, total_in_last_hour = total_in_last_hour, table_name = table_name)
}



ui <- dashboardPage(
  dashboardHeader(title = "NDEXR"),
  dashboardSidebar(
    # Pass in Date objects
    numericInput(inputId = "limit_value", label = "Plot N Seconds", value = 30000, min = 100, max = 1000000),
    textInput(inputId = "search_value", label = "Query Data", value = "Natural Language Processing", placeholder = "Natural Language Processing")
  ),
  dashboardBody(
    # infoBoxes with fill=FALSE
    fluidRow(
      # Dynamic infoBoxes
      infoBoxOutput("progressBox"),
      infoBoxOutput("approvalBox"),
      infoBoxOutput("progressBox2"),
      infoBoxOutput("approvalBox2")
    ),
    fluidRow(
      # Clicking this will increment the progress amount
      plotOutput("all_time_comments")
    ),
    fluidRow(
      plotOutput("all_time_submissions")
    ),
    fluidRow(
      # A static infoBox

      # Dynamic infoBoxes
      tableOutput("search_data")
    ),

    # infoBoxes with fill=TRUE
    # fluidRow(
    #   infoBoxOutput("progressBox2"),
    #   infoBoxOutput("approvalBox2")
    # ),
  )
)

server <- function(input, output) {
  mat_comments_by_second <- get_count("mat_comments_by_second")
  mat_submissions_by_second <- get_count("mat_submissions_by_second")
  mat_comments_total <- mat_comments_by_second$comments_gathered
  mat_submissions_total <- mat_submissions_by_second$comments_gathered
  mat_comments_last_hour <- mat_comments_by_second$total_in_last_hour
  mat_submissions_last_hour <- mat_submissions_by_second$total_in_last_hour

  output$all_time_comments <- renderPlot({
    future({
      plot_stream(limit = as.numeric(input$limit_value), timezone = "MST", add_hours = 1, table = 'mat_comments_by_second')
    })
  })

  output$all_time_submissions <- renderPlot({
    future({
      plot_stream(limit = as.numeric(input$limit_value), timezone = "MST", add_hours = 1, 'mat_submissions_by_second')
    })
  })

  output$progressBox <- renderInfoBox({
    infoBox(
      "Comments Gathered", mat_comments_total,
      icon = icon("list"),
      color = "purple"
    )
  })
  output$approvalBox <- renderInfoBox({
    infoBox(
      "Comments Gathered - Last Hour", mat_comments_last_hour,
      icon = icon("thumbs-up", lib = "glyphicon"),
      color = "yellow"
    )
  })

  # Same as above, but with fill=TRUE
  output$progressBox2 <- renderInfoBox({
    infoBox(
      "Submissions Gathered", mat_submissions_total,
      icon = icon("list"),
      color = "purple", fill = TRUE
    )
  })
  output$approvalBox2 <- renderInfoBox({
    infoBox(
      "Submissions Gathered - Last Hour", mat_submissions_last_hour,
      icon = icon("thumbs-up", lib = "glyphicon"),
      color = "yellow", fill = TRUE
    )
  })
  output$search_data <- renderTable({
    response <- find_posts(search_term = input$search_value, limit = 30) %>%
      transmute(
        created_utc = as_date(created_utc),
        days_ago = as.numeric(Sys.Date() - created_utc),
        author, subreddit, title, permalink, shortlink
      ) %>%
      mutate_all(as.character) %>%
      as_tibble()

    response
  })
}

shinyApp(ui, server)
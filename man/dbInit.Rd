% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/db.R
\name{dbInit}
\alias{dbInit}
\title{Initialize DB}
\usage{
dbInit(
  conn,
  path,
  pattern = "\\\\.(rds|csv|gz)$",
  overwrite = FALSE,
  verbose = TRUE,
  na.strings = "",
  ...
)
}
\arguments{
\item{conn}{a \code{DBIConnection} object, as returned by \code{\link[DBI]{dbConnect}}.}

\item{path}{the path to the directory containing the data files.}

\item{pattern}{an optional regular expression. Only file names which match the regular expression will be used.}

\item{overwrite}{if \code{TRUE}, an existing table of the same name will be overwritten. This argument doesn't change behavior if the table does not exist yet.}

\item{verbose}{if \code{TRUE}, print on progress.}

\item{na.strings}{a character vector of strings which are to be interpreted as \code{NA} values by \code{\link[data.table]{fread}}.}

\item{...}{additional arguments passed to \code{\link[data.table]{fread}}.}
}
\value{
\code{NULL}
}
\description{
Create a SQL database from flat files.
}
\examples{
\dontrun{
library(RSQLite)
conn <- dbConnect(RSQLite::SQLite(), "crsp.db")
path <- "path/to/crsp/sazYYYYMM_r"
dbInit(conn, path)
}

}

#' Initialize DB
#'
#' Create a SQL database from flat files.
#'
#' @param conn a \code{DBIConnection} object, as returned by \code{\link[DBI]{dbConnect}}.
#' @param path the path to the directory containing the data files.
#' @param pattern an optional regular expression. Only file names which match the regular expression will be used.
#' @param overwrite if \code{TRUE}, an existing table of the same name will be overwritten. This argument doesn't change behavior if the table does not exist yet.
#' @param verbose if \code{TRUE}, print on progress.
#' @param na.strings a character vector of strings which are to be interpreted as \code{NA} values by \code{\link[data.table]{fread}}.
#' @param ... additional arguments passed to \code{\link[data.table]{fread}}.
#'
#' @returns
#' \code{NULL}
#'
#' @examples
#' \dontrun{
#' library(RSQLite)
#' conn <- dbConnect(RSQLite::SQLite(), "crsp.db")
#' path <- "path/to/crsp/sazYYYYMM_r"
#' dbInit(conn, path)
#' }
#'
#' @export
#'
dbInit <- function(conn, path, pattern = "\\.(rds|csv|gz)$", overwrite = FALSE, verbose = TRUE,  na.strings = "", ...) {
  for(file in list.files(path = path, pattern = pattern, full.names = TRUE))
    dbImportTable(conn, file = file, overwrite = overwrite, verbose = verbose, na.strings = na.strings, ...)
}

#' Export SQL Query to file
#'
#' @param conn a \code{DBIConnection} object, as returned by \code{\link[DBI]{dbConnect}}.
#' @param sql the sql query or path to an .sql file.
#' @param file output file name.
#' @param verbose if \code{TRUE}, print on progress.
#' @param ... additional arguments passed to \code{\link[data.table]{fwrite}}.
#'
#' @returns
#' \code{NULL}
#'
#' @export
#'
dbExport <- function(conn, sql, file, verbose = TRUE, ...){
  if(verbose)
    cat("Running query... ")
  
  if(endsWith(sql, ".sql"))
    sql <- readChar(sql, file.info(sql)$size)
  x <- dbGetQuery(conn, sql)

  if(verbose)
    cat("writing file... ")
  fwrite(x, file = file, showProgress = verbose, ...)

  if(verbose)
    cat(sprintf("\n\nFile saved in %s\n", file))
}

#' Import Table
#'
#' @param conn a \code{DBIConnection} object, as returned by \code{\link[DBI]{dbConnect}}.
#' @param file the file to import.
#' @param overwrite if \code{TRUE}, an existing table of the same name will be overwritten. This argument doesn't change behavior if the table does not exist yet.
#' @param verbose if \code{TRUE}, print on progress.
#' @param na.strings a character vector of strings which are to be interpreted as \code{NA} values by \code{\link[data.table]{fread}}.
#' @param ... additional arguments passed to \code{\link[data.table]{fread}}.
#'
#' @returns
#' \code{NULL}
#'
dbImportTable <- function(conn, file, overwrite, verbose, na.strings, ...) {
  if(verbose)
    cat(sprintf("Import: %s\n", file))

  name <- gsub("\\..*$", "", basename(file))
  exists <- dbExistsTable(conn, name = name)
  if(exists & !overwrite){
    if(verbose)
      cat(sprintf("  -> skipped. Table %s already exists and overwrite=FALSE.\n", name))
    return(invisible())
  }

  if(verbose)
    cat("  ->  reading file...\n")
  if(endsWith(file, ".rds"))
    x <- readRDS(file)
  else
    x <- fread(file = file, na.strings = na.strings, showProgress = FALSE, ...)

  if(verbose)
    cat("  ->  sanitizing data...\n")
  x <- dbSanitizeData(x)

  if(verbose)
    cat(sprintf("  ->  %s table %s...\n", ifelse(exists, "overwriting", "creating"), name))
  dbWriteTable(conn, name = name, value = x, overwrite = overwrite, row.names = FALSE)

  if(verbose)
    cat("  ->  creating index...\n")
  dbCreateIndex(conn, name)

  if(verbose)
    cat("  ->  done!\n")
}

#' Create Index
#'
#' @param conn a \code{DBIConnection} object, as returned by \code{\link[DBI]{dbConnect}}.
#' @param name the table name.
#' @param index vector of column names to index the table.
#'
#' @returns
#' \code{NULL}
#' 
#' @export
#'
dbCreateIndex <- function(conn, name, index = NULL){
  pk <- c(
    "sfz_del" = "KYPERMNO, DLSTDT",
    "sfz_mdel" = "KYPERMNO, MDLSTDT",
    "sfz_dis" = "KYPERMNO, EXDT, DISTCD, ACPERM",
    "sfz_nam" = "KYPERMNO, NAMEDT",
    "sfz_ndi" = "KYPERMNO, TRTSDT",
    "sfz_hdr" = "KYPERMNO",
    "sfz_shr" = "KYPERMNO, SHRSDT",
    "sfz_dp_dly" = "KYPERMNO, CALDT",
    "sfz_ds_dly" = "KYPERMNO, CALDT",
    "sfz_mth" = "KYPERMNO, MCALDT",
    "sfz_agg_mth" = "KYPERMNO, YYYYMM",
    "sfz_agg_qtr" = "KYPERMNO, YYYYQ",
    "sfz_agg_ann" = "KYPERMNO, YYYY",
    "sfz_mbr" = "KYPERMNO, KEYSET, MBRDT",
    "sfz_portd" = "KYPERMNO, KEYSET, ANNUAL",
    "sfz_portm" = "KYPERMNO, KEYSET, ANNUAL",
    "sfz_indhdr" = "KYINDNO",
    "sfz_rb" = "KYINDNO, RBBEGDT",
    "sfz_dind" = "KYINDNO, CALDT",
    "sfz_mind" = "KYINDNO, MCALDT"
  )

  if(!is.null(index))
    cols <- paste(index, collapse = ", ")
  else if(name %in% names(pk))
    cols <- pk[name]
  else
    return(invisible())
  
  if(dbExistsTable(conn, name = name)){
    sql <- sprintf("CREATE INDEX idx_%s ON %s (%s)", name, name, cols)
    dbExecute(conn, sql)  
  }
  
  return(invisible())
}

#' Sanitize Data
#'
#' @param x a data frame.
#'
#' @returns
#' \code{data.frame}
#'
dbSanitizeData <- function(x){
  x <- as.data.frame(x)
  colnames(x) <- tolower(colnames(x))

  for(i in colnames(x))
    if(inherits(x[,i], 'Date'))
      x[,i] <- as.integer(format(x[,i], format="%Y%m%d"))

  if("itemlongdesc" %in% colnames(x))
    x$itemlongdesc <- gsub("[\x80-\xff]", "", x$itemlongdesc)

  return(x)
}

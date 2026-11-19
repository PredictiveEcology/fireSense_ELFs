#' Write a raster file so that a reader never sees it half-written
#'
#' `write` writes the raster to a temporary file in the target's folder, which is then renamed over
#' `target` (a rename replaces the file in one step, so a job opening `target` meanwhile gets either the
#' old complete file or the new one). The same `file.rename()` idiom as reproducible's internal
#' `.renameOver`, which is not exported.
#'
#' @param target the file to write.
#' @param write a function of one argument, the file to write to, that writes the raster there.
#' @return the raster, read from `target`.
writeRasterAtomic <- function(target, write) {
  tmp <- tempfile(pattern = paste0(".tmp_", tools::file_path_sans_ext(basename(target)), "_"),
                  tmpdir = dirname(target), fileext = paste0(".", tools::file_ext(target)))
  on.exit(unlink(tmp), add = TRUE)
  write(tmp)
  if (!file.rename(tmp, target)) stop("could not rename ", tmp, " to ", target)
  terra::rast(target)
}

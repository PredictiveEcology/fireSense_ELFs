## THIS FILE IS EXPECTED TO DIFFER BETWEEN `development` AND THE CLEANUP BRANCH.
##
## The cleanup removed the SpaDES template's `plot` and `save` branches from
## doEvent.fireSense_ELFs(), with the template functions plotFun(), ggplotFn() and Save().
## Nothing schedules those events: init never did (the scheduleEvent() lines were commented
## out), and no other module or project script does. But a caller could schedule them by
## hand, and what happens then has changed:
##
##   event    on development                                    on the cleanup branch
##   "save"   runs silently, does nothing                       warns "Undefined event type"
##   "plot"   draws a histogram of 10 random numbers            warns "Undefined event type"
##            (the template's example plot, unrelated to ELFs)
##
## The two tests below assert the branch's behaviour, so they FAIL on development. Every other
## test file in this suite passes on both.

runOnly <- function(eventType) {
  sim <- toySimInit()
  sim <- SpaDES.core::scheduleEvent(sim, 1, "fireSense_ELFs", eventType, eventPriority = 1)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ## `events` keeps init (Google Drive, national maps) from running
  suppressMessages(SpaDES.core::spades(sim, debug = FALSE,
                                       events = list(fireSense_ELFs = eventType)))
}

test_that("a hand-scheduled `save` event is now an undefined event [differs from development]", {
  expect_warning(runOnly("save"), "Undefined event type: 'save' in module 'fireSense_ELFs'")
})

test_that("a hand-scheduled `plot` event is now an undefined event [differs from development]", {
  expect_warning(runOnly("plot"), "Undefined event type: 'plot' in module 'fireSense_ELFs'")
})

## This one passes on both.
test_that("any other unknown event warns and leaves the simList as it was", {
  out <- NULL
  expect_warning(out <- runOnly("notAnEvent"),
                 "Undefined event type: 'notAnEvent' in module 'fireSense_ELFs'")
  expect_identical(out$.ELFind, "4.3")
  expect_null(out$ELFs) # init did not run
  done <- SpaDES.core::completed(out)
  expect_identical(done$eventType[done$moduleName == "fireSense_ELFs" & done$eventType != ".inputObjects"],
                   "notAnEvent")
})

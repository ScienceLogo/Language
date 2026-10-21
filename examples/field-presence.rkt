#lang sciencelogo
workflow "Check fields and list items"

trial = [period = unknown method = "manual"]
methods = ["manual" "video"]

if period in trial [print "period is present"]
if not (notes in trial) [print "notes is absent"]
if trial.method in methods [print "method is allowed"]

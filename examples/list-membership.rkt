#lang sciencelogo
workflow "Select a timing method"

methods = ["manual" "video"]

interface Timing [
  must [method in ["manual" "video"]]
]

trial = Timing.[method = "manual"]
trial implement Timing

if trial.method in methods [print trial.method]

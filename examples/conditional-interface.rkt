#lang sciencelogo

workflow "Describe pendulum timing methods"

interface "Timing-protocol" [
  version "1"
  must [method]

  if method == "automatic" [
    must [instrument unit = "seconds"]
  ] else if method == "video" [
    must [frame-rate]
  ] else [
    must [observer]
  ]
]

automatic = Timing-protocol.[method = "automatic" instrument = "timer-1"]
video = Timing-protocol.[method = "video" frame-rate = 25]
manual = Timing-protocol.[method = "manual" observer = "researcher"]

automatic implement Timing-protocol
video implement Timing-protocol
manual implement Timing-protocol

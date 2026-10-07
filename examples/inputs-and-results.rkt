#lang sciencelogo

investigate "What should we measure?" [
  do observation-plan "Bean plant" as plan
  print plan

  to observation-plan :plant [
    print :plant
    output "Measure its height each day."
  ]
]

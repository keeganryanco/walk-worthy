# skill: prayer_app_product_logic

## Purpose
Define the product structure for the prayer app.

## Core concept
Prayer -> Action -> Reflection -> Timeline

## Main objects
`PrayerJourney`
- title
- category
- startDate

`PrayerEntry`
- prompt
- userReflection
- actionStep
- completed

`AnsweredPrayer`
- referencePrayer
- notes
- date

## DailyFlow
1. Show prayer prompt
2. Show action step
3. Allow reflection
4. Mark complete

## Rules
Daily flow should take under 60 seconds.

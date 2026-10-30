# Adaptive exercise program

The customer's selected weekdays remain authoritative. A larger exercise library
does not force five sessions per week or silently add unavailable days.

The catalog contains 3 exercises each for chest, back, quadriceps, hamstrings,
glutes and shoulders; 2 each for biceps, triceps and abs. Two calf movements
complete lower-leg coverage. Each exercise has a primary emphasis and its own
technique cues. Labels describe emphasis, not isolation of a muscle head.

Movement references: [NASM exercise library](https://www.nasm.org/workout-exercise-guidance)
and [ACE exercise library](https://www.acefitness.org/resources/everyone/exercise-library/).

At 5 available days and 60 minutes, the split is chest/triceps, back/biceps,
quadriceps/calves, shoulders/abs, hamstrings/glutes. Four days use combined
groups. One to three days use a rotating mixed-group program. Time-limited
sessions rotate the remaining movements across subsequent weeks rather than
claiming all 26 exercises fit every week. Rotation uses the calendar week so
reopening the app does not reset the selection.

The duration selector in Schedule and Workout Plan is saved per local account.
It supports 30, 45, 60, 75 and 90 minutes. The estimate reserves 6 minutes for
preparation and 8 per exercise for working sets, light warm-up, rest and
transitions; it is a planning estimate, not a timer or guaranteed duration.
Today's readiness check-in can shorten the session or recommend rest. It never
increases the time the customer says they have. Future dates and completed or
in-progress sessions are preserved.

The first exercise of each represented group has one separately tracked light
warm-up set. Warm-up is excluded from completed working sets, recorded working
volume and personal records. Beginners and conservative profiles get 2 working
sets per exercise; others get 3. Initial weight is 0, for the customer to choose
an appropriate load rather than being assigned a universal weight.

No database migration is required. Exercise metadata lives in the client catalog
and schedule JSON. Exercise logs continue to sync using the existing schema.
Duration preference and planned schedule are currently device-local, scoped to
the signed-in account; they are not a new Supabase profile field.

Checks: adaptive_program_test covers all 1–7 day / 30–90 minute combinations,
rotation coverage, group targets, warm-up placement and preservation of completed
sessions. workout_date_access_test covers date access and warm-up exclusion from
working-set progress.

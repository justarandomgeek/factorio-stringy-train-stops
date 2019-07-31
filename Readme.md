## Stringy Train Stops

Uses signalstrings to rename train stops, and send trains to them.

To rename a stop, send the string along with signal-stopname.
To send a train to a stop, send the string along with signal-goto.

To program multiple stops, send a series of stops as:

 * signal-schedule = 1-based index in schedule
 * string of destination stop name *OR* the Schedule Rail signal and X&Y coordinates of a rail to go to
 * wait condition: (Multiple wait conditions will be composed with AND)
   * signal-wait-time = time to wait
   * signal-wait-inactivitiy = time to wait
   * signal-wait-empty
   * signal-wait-full
   * signal-wait-circuit - will wait for signal-black
   * signal-wait-passenger - positive values will wait for a passenger, negative will wait for the passenger to get out.

Then send signal-schedule=-1 to send the train to the first stop in the schedule.

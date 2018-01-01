## Stringy Train Stops

Uses signalstrings to rename train stops, and send trains to them.

To rename a stop, send the string along with signal-stopname.
To send a train to a stop, send the string along with signal-goto.

To program multiple stops, send a series of stops as:
 * signal-schedule
 * string of destination stop name
 * wait condition: (only one)
   * signal-wait-time = time to wait
   * signal-wait-inactivitiy = time to wait
   * signal-wait-empty
   * signal-wait-full
   * signal-wait-circuit - will wait for signal-black

Then send signal-schedule=-1 to send the train to the first stop in the schedule.

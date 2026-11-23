-- Delay per lane for one shipper, from Wednesday's tables.
-- Joins each booking to the sailing or flight it was booked on, and compares
-- actual arrival with planned arrival.
--
-- Fill in the one blank: your shipper's ID from project/shippers.md.
-- Bookings whose sailing is not in the schedules table (it departs after
-- October) drop out of the join, so they are not counted.

SELECT
  b.mode,
  b.origin,
  b.destination,
  b.trade_lane,
  COUNT(*) AS shipments,
  ROUND(AVG(DATETIME_DIFF(s.actual_arrival, s.planned_arrival, HOUR)), 1) AS avg_delay_hours,
  ROUND(100 * COUNTIF(DATETIME_DIFF(s.actual_arrival, s.planned_arrival, HOUR) <= 24) / COUNT(*), 1) AS on_time_pct
FROM freight.bookings AS b
JOIN freight.schedules AS s
  ON s.schedule_id = b.schedule_id
WHERE b.shipper_id = 'SHP07'   -- your shipper ID, for example 'SHP00'
GROUP BY b.mode, b.origin, b.destination, b.trade_lane
ORDER BY on_time_pct;

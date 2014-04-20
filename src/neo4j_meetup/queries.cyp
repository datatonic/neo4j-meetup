// find the number of members / guests coming to each meetup
MATCH (e:Event)
OPTIONAL MATCH (e)<-[:TO]-(rsvp {response: "yes"})
return e.name, e.time, count(rsvp) as members, sum(rsvp.guests) AS guests
ORDER BY (members + guests) DESC

// events attended 
MATCH (e:Event)<-[:TO]-(rsvp {response: "yes"})<-[:RSVPD]-(person)
return person.name, count(rsvp) as timesAttended
ORDER BY timesAttended DESC

// what was the last meetup they attended before this one
match (e:Event {id: "167264852"})<-[:TO]-({response: "yes"})-[:RSVPD]-(person)
match (person)-[:RSVPD]->({response: "yes"})-[:TO]->(otherEvent)
WHERE otherEvent <> e AND otherEvent.time < timestamp()
WITH person, otherEvent
ORDER BY person.name, otherEvent.time
RETURN person.name, COUNT(otherEvent) AS count, COLLECT(otherEvent.name)[-1]
ORDER BY count DESC 

// events held at each venue
MATCH (v:Venue)<-[:HELD_AT]-(event)<-[:TO]-(rsvp {response: "yes"})
WHERE event.time < timestamp()
WITH v, COUNT(DISTINCT event) as events, COUNT(rsvp) AS rsvps
RETURN v.name AS venue, events, rsvps, rsvps / events AS rsvpsPerEvent
ORDER BY events DESC

// visualise events at each venue
MATCH (v:Venue)<-[:HELD_AT]-(event)<-[:HOSTED_EVENT]-(group)
OPTIONAL MATCH v-[:ALIAS_OF]->(v2)
RETURN v, event, group

// create time tree

WITH 2011 as startYear
WITH startYear, range(startYear, 2014) AS years, range(1,12) as months
FOREACH(year IN years | 
  MERGE (y:Year {year: year})
  FOREACH(month IN months | 
    CREATE (m:Month {month: month})
    MERGE (m)-[:PART_OF]->(y)
    FOREACH(day IN (CASE 
                      WHEN month IN [1,3,5,7,8,10,12] THEN range(1,31) 
                      WHEN month = 2 THEN 
                        CASE
                          WHEN year % 4 <> 0 THEN range(1,28)
                          WHEN year % 100 <> 0 THEN range(1,29)
                          WHEN year % 400 THEN range(1,29)
                          ELSE range(1,28)
                        END
                      ELSE range(1,30)
                    END) |      
      CREATE (d:Day {day: day})
      MERGE (d)-[:PART_OF]->(m)
    )
  )
)

WITH range(2011, 2014) AS years, range(1,12) as months
FOREACH(year IN years | 
  MERGE (y:Year {year: year})
  FOREACH(month IN months | 
    CREATE (m:Month {month: month})
    MERGE (y)-[:HAS_MONTH]->(m)
    FOREACH(day IN (CASE 
                      WHEN month IN [1,3,5,7,8,10,12] THEN range(1,31) 
                      WHEN month = 2 THEN 
                        CASE
                          WHEN year % 4 <> 0 THEN range(1,28)
                          WHEN year % 100 <> 0 THEN range(1,29)
                          WHEN year % 400 <> 0 THEN range(1,29)
                          ELSE range(1,28)
                        END
                      ELSE range(1,30)
                    END) |      
      CREATE (d:Day {day: day})
      MERGE (m)-[:HAS_DAY]->(d))))

WITH *

MATCH (year:Year)-[:HAS_MONTH]->(month)-[:HAS_DAY]->(day)
WITH year,month,day
ORDER BY year.year, month.month, day.day
WITH collect(day) as days
FOREACH(i in RANGE(0, length(days)-2) | 
    FOREACH(day1 in [days[i]] | 
        FOREACH(day2 in [days[i+1]] | 
            CREATE UNIQUE (day1)-[:NEXT]->(day2))))

// get the previous 5 days 
MATCH (y:Year {year: 2014})-[:HAS_MONTH]->(m:Month {month: 2})-[:HAS_DAY]->(:Day {day: 1})<-[:NEXT*0..5]-(day)
RETURN y,m,day
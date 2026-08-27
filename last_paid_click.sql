select 
sessions.visitor_id,
visit_date,
source as utm_source,
medium as utm_medium,
campaign as utm_campaign,
lead_id,
created_at,
amount,
closing_reason,
status_id
from sessions
full join leads
on sessions.visitor_id = leads.visitor_id 
order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign;
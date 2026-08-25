--1 задание--
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



--2 задание--
SELECT
    s.visit_date,
    COUNT(*) AS visitors_count,
    s.source AS utm_source,
    s.medium AS utm_medium,
    s.campaign AS utm_campaign,
    COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0) AS total_cost,
    COUNT(l.lead_id) AS leads_count,
    COUNT(
        CASE
            WHEN l.closing_reason = 'Успешно реализовано'
              OR l.status_id = 142
            THEN 1
        END
    ) AS purchases_count,
    SUM(
        CASE
            WHEN l.closing_reason = 'Успешно реализовано'
              OR l.status_id = 142
            THEN l.amount
            ELSE 0
        END
    ) AS revenue
FROM sessions s
LEFT JOIN leads l
    ON s.visitor_id = l.visitor_id
LEFT JOIN ya_ads ya
    ON s.source = ya.utm_source
   AND s.medium = ya.utm_medium
   AND s.campaign = ya.utm_campaign
LEFT JOIN vk_ads vk
    ON s.source = vk.utm_source
   AND s.medium = vk.utm_medium
   AND s.campaign = vk.utm_campaign
GROUP BY
    s.visit_date,
    s.source,
    s.medium,
    s.campaign
ORDER BY
    revenue DESC NULLS LAST,
    s.visit_date ASC,
    s.source ASC,
    s.medium ASC,
    s.campaign ASC;
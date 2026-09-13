SELECT
    utm_source,
    SUM(visitors_count) AS visitors_count,
    SUM(leads_count) AS leads_count,
    SUM(purchases_count) AS purchases_count,
    SUM(total_cost) AS total_cost,
    SUM(revenue) AS revenue,

    SUM(total_cost) / NULLIF(SUM(visitors_count), 0) AS cpu,

    SUM(total_cost) / NULLIF(SUM(leads_count), 0) AS cpl,

    SUM(total_cost) / NULLIF(SUM(purchases_count), 0) AS cppu,

    (SUM(revenue) - SUM(total_cost))
        / NULLIF(SUM(total_cost), 0) * 100 AS roi

FROM marketing_data
GROUP BY utm_source
ORDER BY roi DESC;

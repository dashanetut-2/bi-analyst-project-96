WITH ads AS (
    SELECT DISTINCT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    FROM vk_ads
    UNION ALL
    SELECT DISTINCT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    FROM ya_ads
),
sessions_ads AS (
    SELECT DISTINCT
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        s.content
    FROM sessions s
    WHERE EXISTS (
        SELECT 1
        FROM ads a
        WHERE DATE(s.visit_date) = a.campaign_date
          AND s.source = a.utm_source
          AND s.medium = a.utm_medium
          AND s.campaign = a.utm_campaign
          AND s.content = a.utm_content
    )
),
sessions_agg AS (
    SELECT
        DATE(visit_date) AS visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        COUNT(*) AS visitors_count
    FROM sessions_ads
    GROUP BY
        DATE(visit_date),
        source,
        medium,
        campaign
),
ads_agg AS (
    SELECT
        campaign_date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
),
lead_sessions AS (
    SELECT
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM leads l
    JOIN sessions_ads s
        ON l.visitor_id = s.visitor_id
        AND s.visit_date <= l.created_at
),
leads_agg AS (
    SELECT
        DATE(visit_date) AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(DISTINCT lead_id) AS leads_count,
        COUNT(DISTINCT CASE
            WHEN closing_reason = 'Успешно реализовано'
                OR status_id = 142
            THEN lead_id
        END) AS purchases_count,
        SUM(CASE
            WHEN closing_reason = 'Успешно реализовано'
                OR status_id = 142
            THEN amount
            ELSE 0
        END) AS revenue
    FROM lead_sessions
    WHERE rn = 1
    GROUP BY
        DATE(visit_date),
        utm_source,
        utm_medium,
        utm_campaign
)
SELECT
    s.visit_date,
    s.visitors_count,
    s.utm_source,
    s.utm_medium,
    s.utm_campaign,
    a.total_cost,
    COALESCE(l.leads_count, 0) AS leads_count,
    COALESCE(l.purchases_count, 0) AS purchases_count,
    l.revenue
FROM sessions_agg s
LEFT JOIN ads_agg a
    ON s.visit_date = a.visit_date
    AND s.utm_source = a.utm_source
    AND s.utm_medium = a.utm_medium
    AND s.utm_campaign = a.utm_campaign
LEFT JOIN leads_agg l
    ON s.visit_date = l.visit_date
    AND s.utm_source = l.utm_source
    AND s.utm_medium = l.utm_medium
    AND s.utm_campaign = l.utm_campaign
ORDER BY
    l.revenue DESC NULLS LAST,
    s.visit_date ASC,
    s.visitors_count DESC,
    s.utm_source ASC,
    s.utm_medium ASC,
    s.utm_campaign ASC
LIMIT 15;

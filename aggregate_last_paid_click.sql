WITH lead_visits AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id
        AND l.created_at >= s.visit_date
    WHERE s.medium IN (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
),
visitors AS (
    SELECT
        visitor_id,
        visit_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY visitor_id
            ORDER BY visit_date DESC
        ) AS rn
    FROM (
        SELECT
            visitor_id,
            visit_date,
            source AS utm_source,
            medium AS utm_medium,
            campaign AS utm_campaign
        FROM sessions
        WHERE medium IN (
            'cpc',
            'cpm',
            'cpa',
            'youtube',
            'cpp',
            'tg',
            'social'
        )
    ) AS s
),
ads AS (SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    FROM vk_ads
    UNION ALL
    SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    FROM ya_ads),
ads_aggregated AS (
    SELECT
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ads
    GROUP BY
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
)
SELECT
    v.visit_date,
    COUNT(DISTINCT v.visitor_id) AS visitors_count,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    COALESCE(a.total_cost, 0) AS total_cost,
    COUNT(DISTINCT lv.lead_id) AS leads_count,
    COUNT(DISTINCT CASE
        WHEN lv.closing_reason = 'Успешно реализовано'
            OR lv.status_id = 142
        THEN lv.lead_id
    END) AS purchases_count,
    COALESCE(SUM(CASE
        WHEN lv.closing_reason = 'Успешно реализовано'
            OR lv.status_id = 142
        THEN lv.amount
        ELSE 0
    END), 0) AS revenue
FROM visitors AS v
LEFT JOIN lead_visits AS lv
    ON v.visitor_id = lv.visitor_id
    AND lv.rn = 1
LEFT JOIN ads_aggregated AS a
    ON v.visit_date = a.visit_date
    AND v.utm_source = a.utm_source
    AND v.utm_medium = a.utm_medium
    AND v.utm_campaign = a.utm_campaign
WHERE v.rn = 1
GROUP BY
    v.visit_date,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    a.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
LIMIT 15;

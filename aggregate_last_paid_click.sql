WITH paid_sessions AS (
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
),
last_visitor_session AS (
    SELECT 
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY visitor_id
            ORDER BY visit_date DESC
        ) AS rn
    FROM paid_sessions
),
daily_visitors AS (
    SELECT 
        visit_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(DISTINCT visitor_id) AS visitors_count
    FROM last_visitor_session
    WHERE rn = 1
    GROUP BY 1, 2, 3, 4
),
lead_sessions AS (
    SELECT 
        l.lead_id,
        l.visitor_id,
        l.amount,
        l.created_at,
        l.closing_reason,
        l.status_id,
        s.visit_date,
        s.utm_source,
        s.utm_medium,
        s.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM leads l
    JOIN paid_sessions s
        ON l.visitor_id = s.visitor_id
        AND s.visit_date <= l.created_at
),
attributed_leads AS (
    SELECT 
        lead_id,
        visitor_id,
        visit_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        CASE 
            WHEN closing_reason = 'Успешно реализовано'
                OR status_id = 142
            THEN 1 
            ELSE 0 
        END AS is_purchase,
        CASE 
            WHEN closing_reason = 'Успешно реализовано'
                OR status_id = 142
            THEN COALESCE(amount, 0) 
            ELSE 0 
        END AS revenue
    FROM lead_sessions
    WHERE rn = 1
),
lead_metrics AS (
    SELECT 
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(DISTINCT lead_id) AS leads_count,
        SUM(is_purchase) AS purchases_count,
        SUM(revenue) AS revenue
    FROM attributed_leads
    GROUP BY 1, 2, 3, 4
),
all_ads AS (SELECT 
        campaign_date AS ad_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    FROM vk_ads
    UNION ALL
    SELECT 
        campaign_date AS ad_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    FROM ya_ads),
ads_aggregated AS (
    SELECT 
        ad_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM all_ads
    GROUP BY 1, 2, 3, 4
),
aggregated AS (
    SELECT
        COALESCE(dv.visit_date, lm.visit_date, aa.visit_date) AS visit_date,
        COALESCE(dv.utm_source, lm.utm_source, aa.utm_source) AS utm_source,
        COALESCE(dv.utm_medium, lm.utm_medium, aa.utm_medium) AS utm_medium,
        COALESCE(dv.utm_campaign, lm.utm_campaign, aa.utm_campaign) AS utm_campaign,
        COALESCE(dv.visitors_count, 0) AS visitors_count,
        COALESCE(aa.total_cost, 0) AS total_cost,
        COALESCE(lm.leads_count, 0) AS leads_count,
        COALESCE(lm.purchases_count, 0) AS purchases_count,
        COALESCE(lm.revenue, 0) AS revenue
    FROM daily_visitors dv
    FULL OUTER JOIN lead_metrics lm
        ON dv.visit_date = lm.visit_date
        AND dv.utm_source = lm.utm_source
        AND dv.utm_medium = lm.utm_medium
        AND dv.utm_campaign = lm.utm_campaign
    FULL OUTER JOIN ads_aggregated aa
        ON COALESCE(dv.visit_date, lm.visit_date) = aa.visit_date
        AND COALESCE(dv.utm_source, lm.utm_source) = aa.utm_source
        AND COALESCE(dv.utm_medium, lm.utm_medium) = aa.utm_medium
        AND COALESCE(dv.utm_campaign, lm.utm_campaign) = aa.utm_campaign
)
SELECT
    visit_date,
    visitors_count,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    leads_count,
    purchases_count,
    revenue
FROM aggregated
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
LIMIT 15;

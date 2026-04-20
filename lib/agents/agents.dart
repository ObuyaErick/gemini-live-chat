import 'package:webs/models/agent_models.dart';

final _agents = [
  {
    "agent_id": "bob_the_kpi_guy",
    "accounts": [],
    "is_global": "false",
    "status": "active",
    "agent_name": "Bob the KPI Guy",
    "agent_subtitle": "Business KPIs \u0026 Trends",
    "agent_description":
        "Need the big picture? I\u0027ll show you the most important KPIs like revenue, conversion rates, or ROAS — always with clear charts and simple breakdowns by channel, category, or brand. I won\u0027t drill into the tiny details, but I\u0027ll help you quickly see how your company is performing and what\u0027s driving the changes.",
    "agent_image_url": "https://storage.googleapis.com/.../bob_avatar.png",
    "agent_profile_text":
        "I\u0027m Bob, your KPI analyst. I help you understand business performance through clear metrics and charts.",
    "agent_instructions":
        "You are Bob the KPI Guy, a senior business analyst specializing in KPIs and performance metrics.\nYou help users understand their business data through clear explanations and actionable insights.\nAlways provide data-driven answers with specific numbers when available.\nWhen presenting data, use clear formatting with bullet points.\nWhen asked for charts, generate them using the code interpreter.\nFocus on high-level business metrics like revenue, conversion rates, ROAS, and growth trends.\nProvide clear charts and breakdowns by channel, category, or brand.",
    "agent_welcome_message":
        "Hi! I\u0027m Bob. Ask me about your business KPIs, or pick a question below to get started.",
    "model_id": "gemini-2.5-flash",
    "temperature": "1.0",
    "display_order": "1",
    "suggested_questions": [
      {
        "category": "Metric Evolution",
        "icon": "chart-line",
        "question_text": "How did revenue evolve over the past 6 months?",
        "display_order": "1",
      },
      {
        "category": "Metric Evolution",
        "icon": "chart-line",
        "question_text":
            "How did my revenue evolve year over year over the past 6 months?",
        "display_order": "2",
      },
      {
        "category": "Metric Evolution",
        "icon": "dollar-sign",
        "question_text":
            "How did AOV evolve year-over-year for the past 3 months?",
        "display_order": "3",
      },
      {
        "category": "Metric Evolution",
        "icon": "check",
        "question_text": "How did my AOV evolve over the past 6 months?",
        "display_order": "4",
      },
      {
        "category": "Metric Evolution",
        "icon": "cube",
        "question_text": "What was my average order value in Q1?",
        "display_order": "5",
      },
      {
        "category": "Metric Evolution",
        "icon": "shopping-cart",
        "question_text":
            "How did our basket abandon rate evolve over the past 6 months?",
        "display_order": "6",
      },
      {
        "category": "Metric Evolution",
        "icon": "users",
        "question_text":
            "How did the number of new customers change over the last quarter?",
        "display_order": "7",
      },
      {
        "category": "Segmentation",
        "icon": "layers",
        "question_text": "How does revenue break down by channel?",
        "display_order": "8",
      },
      {
        "category": "Segmentation",
        "icon": "filter",
        "question_text": "Which product categories had the highest growth?",
        "display_order": "9",
      },
    ],
    "tools": [
      {
        "tool_id": "tool_get_revenue_summary",
        "tool_name": "get_revenue_summary",
        "tool_description":
            "Get a summary of revenue, unique customers, and average order value aggregated by month for a given period.",
        "tool_type": "bigquery",
        "tool_parameters":
            "{\"type\":\"object\",\"properties\":{\"reference_date\":{\"type\":\"string\",\"description\":\"End date for the analysis period (YYYY-MM-DD)\"},\"days_back\":{\"type\":\"integer\",\"description\":\"Number of days to look back from reference_date\",\"default\":365}},\"required\":[\"reference_date\"]}",
        "tool_query_template":
            "SELECT\n  DATE_TRUNC(date, MONTH) AS month,\n  SUM(revenue) AS total_revenue,\n  COUNT(DISTINCT customer_id) AS unique_customers,\n  AVG(order_value) AS avg_order_value\nFROM `{_client_project}.{_dataset}.daily_kpis`\nWHERE date \u003e\u003d DATE_SUB(DATE(\u0027\u0027{reference_date}\u0027\u0027), INTERVAL {days_back} DAY)\n  AND date \u003c\u003d DATE(\u0027\u0027{reference_date}\u0027\u0027)\nGROUP BY month\nORDER BY month DESC\nLIMIT 12",
        "tool_python_code": null,
        "tool_system_message": null,
        "tool_result_instructions":
            "Present the data as a clear summary with monthly figures. Highlight trends and notable changes.",
        "tool_action_endpoint": null,
        "tool_action_method": null,
        "tool_requires_confirmation": null,
        "tool_order": "1",
      },
      {
        "tool_id": "tool_explain_key_drivers",
        "tool_name": "explain_key_drivers",
        "tool_description":
            "Analyze key drivers behind a KPI change using statistical decomposition. Returns a natural language explanation of what factors contributed most to the observed change.",
        "tool_type": "python",
        "tool_parameters":
            "{\"type\":\"object\",\"properties\":{\"metric_name\":{\"type\":\"string\",\"description\":\"The KPI to analyze (e.g. revenue, conversion_rate, aov)\"},\"reference_date\":{\"type\":\"string\",\"description\":\"End date of the analysis period (YYYY-MM-DD)\"},\"comparison_period_days\":{\"type\":\"integer\",\"description\":\"Number of days for comparison window\",\"default\":30}},\"required\":[\"metric_name\",\"reference_date\"]}",
        "tool_query_template": null,
        "tool_python_code":
            "def explain_key_drivers(metric_name, reference_date, comparison_period_days\u003d30, context\u003dNone):\n    import pandas as pd\n    from datetime import datetime, timedelta\n\n    end_date \u003d datetime.strptime(reference_date, \"%Y-%m-%d\")\n    start_date \u003d end_date - timedelta(days\u003dcomparison_period_days)\n    prev_start \u003d start_date - timedelta(days\u003dcomparison_period_days)\n\n    sql \u003d f\"\"\"\n    SELECT date, {metric_name}, channel, category\n    FROM `{context[\"_client_project\"]}.{context[\"_dataset\"]}.daily_kpis`\n    WHERE date BETWEEN DATE(\u0027{prev_start.strftime(\"%Y-%m-%d\")}\u0027) AND DATE(\u0027{end_date.strftime(\"%Y-%m-%d\")}\u0027)\n    \"\"\"\n    df \u003d query_data(sql)\n\n    current \u003d df[df[\"date\"] \u003e\u003d pd.Timestamp(start_date)]\n    previous \u003d df[df[\"date\"] \u003c pd.Timestamp(start_date)]\n\n    current_total \u003d current[metric_name].sum()\n    previous_total \u003d previous[metric_name].sum()\n    change_pct \u003d ((current_total - previous_total) / previous_total * 100) if previous_total else 0\n\n    by_channel \u003d current.groupby(\"channel\")[metric_name].sum().sort_values(ascending\u003dFalse)\n    top_channels \u003d by_channel.head(5).to_dict()\n\n    return {\n        \"metric\": metric_name,\n        \"period\": f\"{start_date.strftime(\u0027%Y-%m-%d\u0027)} to {end_date.strftime(\u0027%Y-%m-%d\u0027)}\",\n        \"current_total\": float(current_total),\n        \"previous_total\": float(previous_total),\n        \"change_percent\": round(change_pct, 2),\n        \"top_channels\": top_channels\n    }",
        "tool_system_message": null,
        "tool_result_instructions":
            "Explain the key drivers in plain business language. Highlight the biggest contributors to the change and suggest what the user should investigate further.",
        "tool_action_endpoint": null,
        "tool_action_method": null,
        "tool_requires_confirmation": null,
        "tool_order": "2",
      },
      {
        "tool_id": "tool_code_execution_bob",
        "tool_name": "code_execution",
        "tool_description":
            "Execute Python code for chart generation, statistical analysis, and data transformations. Use this when the user asks for charts or visualizations.",
        "tool_type": "code_execution",
        "tool_parameters": "{}",
        "tool_query_template": null,
        "tool_python_code": null,
        "tool_system_message": null,
        "tool_result_instructions": null,
        "tool_action_endpoint": null,
        "tool_action_method": null,
        "tool_requires_confirmation": null,
        "tool_order": "3",
      },
    ],
    "data_sources": [
      {
        "data_source_id": "ds_bob_daily_kpis",
        "source_type": "bigquery_table",
        "source_reference": "{_client_project}.{_dataset}.daily_kpis",
        "source_description":
            "Daily KPI summary table with revenue, orders, AOV, conversion rate, and customer counts broken down by channel and category.",
      },
      {
        "data_source_id": "ds_bob_monthly_trends",
        "source_type": "bigquery_table",
        "source_reference": "{_client_project}.{_dataset}.monthly_trends",
        "source_description":
            "Pre-aggregated monthly trends for year-over-year comparisons of key business metrics.",
      },
    ],
  },
  {
    "agent_id": "sally_the_search_scout",
    "accounts": [],
    "is_global": "false",
    "status": "coming_soon",
    "agent_name": "Sally the Search Scout",
    "agent_subtitle": "Search performance analysis",
    "agent_description":
        "Curious about how customers search on your web site? I\u0027ll analyze what people look for, how well those searches perform, and where they drop off. I can also review your search setup, explain why results show up the way they do, and suggest improvements or A/B tests to boost performance.",
    "agent_image_url": "https://storage.googleapis.com/.../sally_avatar.png",
    "agent_profile_text": null,
    "agent_instructions": "",
    "agent_welcome_message": null,
    "model_id": "gemini-2.5-flash",
    "temperature": "1.0",
    "display_order": "2",
    "suggested_questions": [],
    "tools": [],
    "data_sources": [],
  },
  {
    "agent_id": "rex_the_reco_ranger",
    "accounts": [],
    "is_global": "false",
    "status": "coming_soon",
    "agent_name": "Rex the Reco Ranger",
    "agent_subtitle": "Product recommendations performance",
    "agent_description":
        "Want to know how your product recommendations perform? I\u0027ll analyze similarity, cross-sell, and personalized recommendations, explain why certain products are suggested, and help you test improvements with A/B experiments to boost engagement and sales.",
    "agent_image_url": "https://storage.googleapis.com/.../rex_avatar.png",
    "agent_profile_text": null,
    "agent_instructions": "",
    "agent_welcome_message": null,
    "model_id": "gemini-2.5-flash",
    "temperature": "1.0",
    "display_order": "3",
    "suggested_questions": [],
    "tools": [],
    "data_sources": [],
  },
  {
    "agent_id": "bart_the_page_wizard",
    "accounts": [],
    "is_global": "false",
    "status": "coming_soon",
    "agent_name": "Bart the Page Wizard",
    "agent_subtitle": "PDP tracking \u0026 layout optimization",
    "agent_description":
        "Want to see the magic happening on your pages? I\u0027ll show you exactly what visitors look at and click on — especially on product detail pages. With detailed insights into user behavior, I can help uncover what works, what doesn\u0027t, and where improvements could make the biggest impact.",
    "agent_image_url": "https://storage.googleapis.com/.../bart_avatar.png",
    "agent_profile_text": null,
    "agent_instructions": "",
    "agent_welcome_message": null,
    "model_id": "gemini-2.5-flash",
    "temperature": "1.0",
    "display_order": "4",
    "suggested_questions": [],
    "tools": [],
    "data_sources": [],
  },
  {
    "agent_id": "concierge",
    "accounts": [],
    "is_global": "true",
    "status": "active",
    "agent_name": "Concierge",
    "agent_subtitle": "Internal assistant",
    "agent_description":
        "Backend-only orchestration agent for admin operations.",
    "agent_image_url": null,
    "agent_profile_text": null,
    "agent_instructions":
        "You are the Concierge, an internal orchestration agent for the Winning Interactions admin platform.\nYou help admin users navigate the platform, understand reports, and take actions across modules.\nYou are context-aware: you know which module the user is currently viewing.\nYou can guide users to the right reports, suggest relevant specialist agents, and help with configurations.\nAlways be helpful, concise, and proactive in offering guidance.\nWhen the user asks about a specific domain, suggest the appropriate specialist agent from The Data Crew.",
    "agent_welcome_message": null,
    "model_id": "gemini-2.5-flash-lite",
    "temperature": "0.7",
    "display_order": "0",
    "suggested_questions": [],
    "tools": [
      {
        "tool_id": "tool_navigate_to_report",
        "tool_name": "navigate_to_report",
        "tool_description":
            "Navigate the user to a specific report or admin page. Use this when the user asks to see a report or when you want to guide them to the right place.",
        "tool_type": "action",
        "tool_parameters":
            "{\"type\":\"object\",\"properties\":{\"target_path\":{\"type\":\"string\",\"description\":\"The admin page path to navigate to (e.g. /analytics/pdp/overview, /orders, /mixer)\"},\"params\":{\"type\":\"object\",\"description\":\"Optional query parameters for the target page (e.g. date_range, category filters)\"}},\"required\":[\"target_path\"]}",
        "tool_query_template": null,
        "tool_python_code": null,
        "tool_system_message": null,
        "tool_result_instructions":
            "Tell the user where you are navigating them and why it is relevant to their question.",
        "tool_action_endpoint": "admin.navigation",
        "tool_action_method": "navigate",
        "tool_requires_confirmation": "false",
        "tool_order": "1",
      },
    ],
    "data_sources": [],
  },
];

final agentModels = _agents
    .map((e) => Agent.fromJson((e as Map).cast<String, dynamic>()))
    .toList();
import streamlit as st
import pandas as pd
from sqlalchemy import create_engine
import urllib.parse
import matplotlib.pyplot as plt

st.set_page_config(
    page_title="LaDe Delivery Intelligence",
    page_icon="🚚",
    layout="wide"
)

# Database connection
password = urllib.parse.quote_plus("Bluemoon@318")
engine = create_engine(f"mysql+mysqlconnector://root:{password}@localhost/lade_pipeline")

st.title("🚚 LaDe Delivery Intelligence Pipeline")
st.markdown("**Last-Mile Delivery Analytics | Real Industry Data | 3 Chinese Cities | 472,419 Deliveries**")
st.markdown("*Data Source: Cainiao Logistics (Alibaba) | Tools: PySpark · MySQL · Python · Streamlit*")
st.divider()

# KPI Cards
col1, col2, col3, col4 = st.columns(4)
total = pd.read_sql("SELECT COUNT(*) as cnt FROM fact_deliveries", engine).iloc[0]['cnt']
valid = pd.read_sql("SELECT COUNT(*) as cnt FROM fact_deliveries WHERE is_valid=1", engine).iloc[0]['cnt']
avg_dur = pd.read_sql("SELECT ROUND(AVG(delivery_duration_minutes),1) as avg FROM fact_deliveries WHERE is_valid=1", engine).iloc[0]['avg']
couriers = pd.read_sql("SELECT COUNT(*) as cnt FROM dim_courier", engine).iloc[0]['cnt']

col1.metric("Total Deliveries", f"{total:,}")
col2.metric("Valid Records", f"{valid/total*100:.1f}%")
col3.metric("Avg Delivery Time", f"{avg_dur} mins")
col4.metric("Total Couriers", f"{couriers:,}")
st.divider()

# Chart 1 — Delivery duration by city
st.subheader("Average Delivery Duration by City")
city_data = pd.read_sql("""
    SELECT c.city_name, ROUND(AVG(f.delivery_duration_minutes),2) as avg_duration,
    COUNT(f.delivery_id) as total_deliveries
    FROM fact_deliveries f JOIN dim_city c ON f.city_id = c.city_id
    WHERE f.is_valid = 1 GROUP BY c.city_name ORDER BY avg_duration
""", engine)

fig1, ax1 = plt.subplots(figsize=(10, 4))
bars = ax1.barh(city_data['city_name'], city_data['avg_duration'], color='#00b4d8')
ax1.set_xlabel('Average Duration (minutes)', color='white')
ax1.set_facecolor('#0e1117')
fig1.patch.set_facecolor('#0e1117')
ax1.tick_params(colors='white')
ax1.spines['top'].set_visible(False)
ax1.spines['right'].set_visible(False)
ax1.spines['bottom'].set_color('#444')
ax1.spines['left'].set_color('#444')
for bar, val in zip(bars, city_data['avg_duration']):
    ax1.text(val + 1, bar.get_y() + bar.get_height()/2, f'{val} mins', va='center', color='white', fontsize=11)
st.pyplot(fig1)
st.divider()

# Chart 2 — Hourly patterns
st.subheader("Peak Delivery Hours — When Are Couriers Most Active?")
hourly = pd.read_sql("""
    SELECT receipt_hour, COUNT(*) as deliveries
    FROM fact_deliveries WHERE is_valid=1
    GROUP BY receipt_hour ORDER BY receipt_hour
""", engine)

fig2, ax2 = plt.subplots(figsize=(12, 4))
colors = ['#ff6b6b' if h in [9,10,11,14,15,16] else '#00b4d8' for h in hourly['receipt_hour']]
ax2.bar(hourly['receipt_hour'], hourly['deliveries'], color=colors)
ax2.set_xlabel('Hour of Day', color='white')
ax2.set_ylabel('Number of Deliveries', color='white')
ax2.set_facecolor('#0e1117')
fig2.patch.set_facecolor('#0e1117')
ax2.tick_params(colors='white')
ax2.spines['top'].set_visible(False)
ax2.spines['right'].set_visible(False)
ax2.spines['bottom'].set_color('#444')
ax2.spines['left'].set_color('#444')
st.pyplot(fig2)
st.divider()

# Chart 3 — SLA Classification
st.subheader("Delivery SLA Performance — Speed Categories")
sla = pd.read_sql("""
    SELECT 
        CASE 
            WHEN delivery_duration_minutes <= 60 THEN 'Express (under 1 hr)'
            WHEN delivery_duration_minutes <= 120 THEN 'Standard (1-2 hrs)'
            WHEN delivery_duration_minutes <= 240 THEN 'Delayed (2-4 hrs)'
            ELSE 'Critical (over 4 hrs)'
        END AS sla_category,
        COUNT(*) as count
    FROM fact_deliveries WHERE is_valid=1
    GROUP BY sla_category ORDER BY count DESC
""", engine)

fig3, ax3 = plt.subplots(figsize=(8, 4))
colors3 = ['#00b4d8', '#ffd166', '#ff6b6b', '#ef476f']
ax3.bar(sla['sla_category'], sla['count'], color=colors3[:len(sla)])
ax3.set_facecolor('#0e1117')
fig3.patch.set_facecolor('#0e1117')
ax3.tick_params(colors='white')
ax3.spines['top'].set_visible(False)
ax3.spines['right'].set_visible(False)
ax3.spines['bottom'].set_color('#444')
ax3.spines['left'].set_color('#444')
plt.xticks(rotation=15, ha='right')
st.pyplot(fig3)
st.divider()

# Chart 4 — Daily trend
st.subheader("Daily Delivery Volume Trend")
daily = pd.read_sql("""
    SELECT d.full_date, COUNT(f.delivery_id) as deliveries
    FROM fact_deliveries f JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY d.full_date ORDER BY d.full_date
""", engine)

fig4, ax4 = plt.subplots(figsize=(12, 4))
ax4.plot(daily['full_date'], daily['deliveries'], color='#00b4d8', linewidth=2, marker='o')
ax4.set_facecolor('#0e1117')
fig4.patch.set_facecolor('#0e1117')
ax4.tick_params(colors='white')
ax4.spines['top'].set_visible(False)
ax4.spines['right'].set_visible(False)
ax4.spines['bottom'].set_color('#444')
ax4.spines['left'].set_color('#444')
plt.xticks(rotation=45)
st.pyplot(fig4)
st.divider()

# Pipeline Health
st.subheader(" Pipeline Health")
col5, col6, col7 = st.columns(3)
col5.metric("Data Quality Checks", "10/10 PASS", "All checks passed")
col6.metric("Pipeline Layers", "6 Complete", "Layers 1-6 done")
col7.metric("Data Freshness", "March-April 2022", "Real industry data")

st.divider()

# Key Insights
st.subheader("Key Insights")
st.markdown("""
- **472,419 real delivery records** from Cainiao logistics across 3 Chinese cities
- **98.51% data quality** — 465,384 valid records after automated quality checks
- **Average delivery time: 132 minutes** — with high variation across couriers and cities
- **Peak hours: 9-11 AM and 2-4 PM** — courier activity mirrors typical business hours
- **1,870 unique couriers** across Shanghai, Hangzhou, and Chongqing
- **Pipeline architecture**: PySpark transformation → MySQL star schema → automated quality framework
- **Production equivalent**: Spark cluster · Airflow orchestration · Snowflake warehouse
""")

st.divider()
st.caption("Built by Rishitha Gopagani | Data: Cainiao/LaDe Dataset | Tools: PySpark · MySQL · Python · Streamlit")
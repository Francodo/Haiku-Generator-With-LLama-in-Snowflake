# Import python packages
import os
import streamlit as st
from snowflake.snowpark.exceptions import SnowparkSQLException


st.title(f":pen: Haiku Generator App :balloon:")


st.write(
  """**About This App**: A haiku is a short Japanese poetic form, traditionally 5–7–5 syllables that captures a fleeting moment or vivid image in just three lines. Because the format is compact and expressive, it makes a great testbed for pairing a lightweight Streamlit interface with a Snowflake-backed LLM (gen_haiku) to turn any topic into a three-line snapshot on demand.

**The Goal**: (1) Demonstrate how to genrate Haikus using Snowflake function that calls llama3.1-70b (LLM).
(2) Create a table to store the search history, with buttons to DISPLAY OR HIDE the Haiku history table as an option.

Here are the steps:
1. Create Database and Schema in Snowflake (as in SF_LLM.PUBLIC)
2. Create a table in Snowflake (as in CREATE OR Replace TABLE SF_LLM.PUBLIC.generated_haikus (
    topic STRING,
    haiku STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
); )

3. Create a function to generate Haikus in snawflake sql (as in CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
#$$
  AI_COMPLETE(
    'llama3.1-70b',
    'When I give you a topic, you will write a haiku about that topic. Respond with only the haiku.\n\nTopic: ' || PROMPT
  )::VARCHAR
#$$; )

4. Create Python code in Streamlit for the UI (as below).
   
  Check out easy-to-follow guides at
  [docs.streamlit.io](https://docs.streamlit.io).
"""
)

st.write("**Enter the topic of your choice to get back an original Haiku!**")


# Create a database connection to Snowflake
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()


# --- 1. Initialize Session State ---
# Streamlit reruns the entire script on every interaction (typing, clicking a button, moving a slider).
# Storing values in st.session_state preserves data across reruns instead of resetting it to defaults.
if "last_saved_topic" not in st.session_state:
    st.session_state.last_saved_topic = None  # Tracks the most recent topic already generated & saved
if "last_haiku" not in st.session_state:
    st.session_state.last_haiku = None        # Caches the latest generated haiku text for display
if "show_history" not in st.session_state:
    st.session_state.show_history = False     # Controls whether the history table stays visible across reruns

# --- 2. Capture & Sanitize User Input ---
# .strip() removes leading/trailing whitespace so blank or space-only inputs don't trigger LLM calls.
topic_entered = st.text_input("**Haiku Topic**", placeholder="e.g., misty mountains at dawn").strip()

if topic_entered:
    st.write("**The current Haiku topic is**:", topic_entered)

    # Guard against duplicate LLM calls and duplicate table inserts on unrelated reruns
    # (for example, when the user clicks "DISPLAY MY HAIKU SEARCH HISTORY" after entering a topic).
    if topic_entered != st.session_state.last_saved_topic:
        try:
            with st.spinner("Crafting and saving your haiku..."):
                # Use bind parameters (?) instead of string concatenation to safely handle apostrophes/quotes
                # and prevent SQL injection. .collect() forces eager execution of the Snowpark query.
                rows = session.sql(
                    "SELECT SF_LLM.PUBLIC.GEN_HAIKU(?) AS HAIKU",
                    params=[topic_entered],
                ).collect()

                haiku_text = rows[0]["HAIKU"] if rows and rows[0]["HAIKU"] else None

                if haiku_text:
                    # Persist both the topic and generated haiku to Snowflake; created_at defaults in SQL.
                    session.sql(
                        "INSERT INTO SF_LLM.PUBLIC.generated_haikus (topic, haiku) VALUES (?, ?)",
                        params=[topic_entered, haiku_text],
                    ).collect()

                    # Update session state so this topic won't re-generate on subsequent reruns
                    st.session_state.last_saved_topic = topic_entered
                    st.session_state.last_haiku = haiku_text
                else:
                    st.warning("No haiku was returned. Please try a different topic.")
        except SnowparkSQLException as e:
            # Surface Snowflake compilation or runtime errors cleanly in the UI
            st.error(f"Snowflake SQL error: {e}")

# --- 3. Display the Latest Generated Haiku ---
# Rendering from st.session_state keeps the haiku visible even when other widgets cause a rerun.
if st.session_state.last_haiku:
    st.subheader(f"Here is the Haiku for: {st.session_state.last_saved_topic}")
    st.markdown(st.session_state.last_haiku)

st.divider()

# --- 4. Style Action Buttons with Scoped CSS ---
# Streamlit doesn't have a native background_color arg on st.button(), so we inject light CSS
# targeting button elements (plus a hover state) to give them a clean grey appearance.
st.markdown(
    """
    <style>
    div.stButton > button,
    [data-testid="stButton"] > button {
        background-color: #e5e7eb;
        color: #111827;
        border: 1px solid #cbd5e1;
        font-weight: 600;
    }
    div.stButton > button:hover,
    [data-testid="stButton"] > button:hover {
        background-color: #d1d5db;
        color: #111827;
        border-color: #94a3b8;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

# --- 5. History Toggle Controls ---
# Place two explicit buttons side-by-side and pass unique `key` values so Streamlit never confuses
# element IDs. Each button explicitly sets show_history rather than toggling blindly.
col_show, col_hide = st.columns(2)
with col_show:
    if st.button("DISPLAY MY HAIKU SEARCH HISTORY", key="btn_show_history"):
        st.session_state.show_history = True
with col_hide:
    if st.button("HIDE MY HAIKU SEARCH HISTORY", key="btn_hide_history"):
        st.session_state.show_history = False

# --- 6. Conditional History Query & Table Rendering ---
# Only query Snowflake when show_history is True so normal page loads and haiku generations
# don't incur unnecessary warehouse reads.
if st.session_state.show_history:
    st.subheader("Recent Haikus")
    limit_rows = st.slider("Number of recent haikus to show", min_value=5, max_value=50, value=10, step=5)

    try:
        # Order newest-first, cap rows with LIMIT, and convert to Pandas (.to_pandas()) for st.dataframe().
        recent_df = session.sql(
            """
            SELECT topic, haiku, created_at
            FROM SF_LLM.PUBLIC.generated_haikus
            ORDER BY created_at DESC
            LIMIT ?
            """,
            params=[limit_rows],
        ).to_pandas()

        st.dataframe(recent_df, use_container_width=True, hide_index=True)
    except SnowparkSQLException as e:
        st.error(f"Could not load recent haikus: {e}")